import Foundation
import Combine
import HealthKit

struct CardioWorkout: Identifiable, Equatable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let duration: TimeInterval
    let distanceMiles: Double?
    let activeCalories: Double?
    let sourceName: String

    var statsSummary: String? {
        var parts: [String] = []
        if let distance = distanceMiles, distance > 0.05 {
            parts.append(String(format: "%.1f mi", distance))
        }
        if let calories = activeCalories, calories > 0 {
            parts.append("\(Int(calories)) cal")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    nonisolated init(workout: HKWorkout, activeCalories: Double?) {
        self.id = workout.uuid
        self.activityType = workout.workoutActivityType
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.sourceName = workout.sourceRevision.source.name
        self.activeCalories = activeCalories

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let sum = workout.statistics(for: distanceType)?.sumQuantity() {
            self.distanceMiles = sum.doubleValue(for: .mile())
        } else if let cyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling),
                  let sum = workout.statistics(for: cyclingType)?.sumQuantity() {
            self.distanceMiles = sum.doubleValue(for: .mile())
        } else if let totalDistance = workout.legacyTotalDistance {
            self.distanceMiles = totalDistance.doubleValue(for: .mile())
        } else {
            self.distanceMiles = nil
        }
    }
}

private extension HKWorkout {
    /// Some sources (e.g. Garmin Connect) save workouts with the pre-iOS 18
    /// totalDistance/totalEnergyBurned fields instead of associated quantity
    /// samples, so `statistics(for:)` returns nil for them. Reading these via
    /// KVC (rather than the deprecated Swift properties directly) is the only
    /// way to fall back to that data without a compiler deprecation warning,
    /// since there is no statistics-based replacement for a workout that
    /// never had per-sample data to begin with.
    nonisolated var legacyTotalDistance: HKQuantity? { value(forKey: "totalDistance") as? HKQuantity }
    nonisolated var legacyTotalEnergyBurned: HKQuantity? { value(forKey: "totalEnergyBurned") as? HKQuantity }
}

extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running: return "Run"
        case .cycling: return "Ride"
        case .walking: return "Walk"
        case .swimming: return "Swim"
        case .hiking: return "Hike"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .yoga: return "Yoga"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core"
        case .stairClimbing: return "Stair Climb"
        default: return "Workout"
        }
    }

    var symbolName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .yoga: return "figure.yoga"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .coreTraining: return "figure.core.training"
        case .stairClimbing: return "figure.stairs"
        default: return "figure.mixed.cardio"
        }
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()
    private let workoutType = HKObjectType.workoutType()
    private let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    private let distanceWalkingRunningType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
    private let distanceCyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
    private let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!

    /// Persisted once the Health permission sheet has been shown, so later launches can
    /// query immediately instead of waiting on the authorization round trip.
    private static let authorizationRequestedKey = "healthKitAuthorizationRequested"

    @Published private(set) var isAuthorized: Bool
    @Published private(set) var recentWorkouts: [CardioWorkout] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Bumped whenever Health may have new data (observer fired, app foregrounded, or
    /// authorization resolved). Views key their fetches on this so they never go stale.
    @Published private(set) var dataVersion = 0

    private var observerQuery: HKObserverQuery?

    private init() {
        isAuthorized = HKHealthStore.isHealthDataAvailable()
            && UserDefaults.standard.bool(forKey: Self.authorizationRequestedKey)
    }

    /// True when the permission sheet has already been presented on this install.
    var hasRequestedAuthorization: Bool {
        UserDefaults.standard.bool(forKey: Self.authorizationRequestedKey)
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationAndFetch() async {
        guard isHealthDataAvailable else {
            errorMessage = "Health data isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(
                toShare: [],
                read: [workoutType, stepCountType, distanceWalkingRunningType, distanceCyclingType, activeEnergyType]
            )
            let wasAuthorized = isAuthorized
            UserDefaults.standard.set(true, forKey: Self.authorizationRequestedKey)
            isAuthorized = true
            errorMessage = nil
            startObservingWorkouts()
            await fetchRecentWorkouts()
            // Views already fetched if we were authorized from launch; only nudge on the transition.
            if !wasAuthorized { dataVersion += 1 }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Call when the app returns to the foreground; workouts may have synced while away.
    func notifyForegrounded() {
        guard isAuthorized else { return }
        dataVersion += 1
    }

    /// Watches for new/changed workouts and asks Health to wake the app when they arrive.
    private func startObservingWorkouts() {
        guard observerQuery == nil else { return }
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, error in
            Task { @MainActor in
                if error == nil {
                    await self?.fetchRecentWorkouts()
                    self?.dataVersion += 1
                }
                completion()
            }
        }
        store.execute(query)
        observerQuery = query
        store.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }

    func fetchRecentWorkouts(limit: Int = 20) async {
        guard isHealthDataAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            recentWorkouts = try await runSampleQuery(predicate: nil, limit: limit)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches every workout within a date range (e.g. a calendar month), with no cap on count.
    func fetchWorkouts(in interval: DateInterval) async -> [CardioWorkout] {
        guard isHealthDataAvailable, isAuthorized else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        // Retry once: queries fail transiently (e.g. protected data unavailable right after unlock).
        for attempt in 0..<2 {
            do {
                return try await runSampleQuery(predicate: predicate, limit: HKObjectQueryNoLimit)
            } catch {
                errorMessage = error.localizedDescription
                if attempt == 0 { try? await Task.sleep(nanoseconds: 1_000_000_000) }
            }
        }
        return []
    }

    /// Total step count over the given interval (e.g. today, or the current week).
    func fetchStepCount(in interval: DateInterval) async -> Int {
        guard isHealthDataAvailable, isAuthorized else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let sum = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(sum))
            }
            store.execute(query)
        }
    }

    private func runSampleQuery(predicate: NSPredicate?, limit: Int) async throws -> [CardioWorkout] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }
            store.execute(query)
        }
        let workouts = samples.compactMap { $0 as? HKWorkout }
        return await withTaskGroup(of: (Int, CardioWorkout).self) { group in
            for (index, workout) in workouts.enumerated() {
                group.addTask {
                    let calories = await self.activeCalories(for: workout)
                    return (index, CardioWorkout(workout: workout, activeCalories: calories))
                }
            }
            var results = [CardioWorkout?](repeating: nil, count: workouts.count)
            for await (index, cardioWorkout) in group {
                results[index] = cardioWorkout
            }
            return results.compactMap { $0 }
        }
    }

    /// Determines active-calorie burn for a workout, preferring the number reported by
    /// whichever app/device synced the workout (e.g. Garmin Connect, Strava, Fitbit) over
    /// Apple Health's cross-source aggregate, since sources like Garmin often write a
    /// single authoritative calorie total that differs from what Health computes when
    /// merging samples from multiple sources (e.g. an Apple Watch also worn that day).
    private func activeCalories(for workout: HKWorkout) async -> Double? {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return workout.legacyTotalEnergyBurned?.doubleValue(for: .kilocalorie())
        }
        if let sourceCalories = await sourceMatchedActiveEnergy(energyType: energyType, workout: workout),
           sourceCalories > 0 {
            return sourceCalories
        }
        if let sum = workout.statistics(for: energyType)?.sumQuantity() {
            return sum.doubleValue(for: .kilocalorie())
        }
        return workout.legacyTotalEnergyBurned?.doubleValue(for: .kilocalorie())
    }

    private func sourceMatchedActiveEnergy(energyType: HKQuantityType, workout: HKWorkout) async -> Double? {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(from: workout),
            HKQuery.predicateForObjects(from: workout.sourceRevision.source)
        ])
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()))
            }
            store.execute(query)
        }
    }
}
