import Foundation
import Combine
import HealthKit

struct CardioWorkout: Identifiable {
    let id: UUID
    let activityType: HKWorkoutActivityType
    let startDate: Date
    let duration: TimeInterval
    let distanceMiles: Double?
    let activeCalories: Double?
    let sourceName: String

    init(workout: HKWorkout) {
        self.id = workout.uuid
        self.activityType = workout.workoutActivityType
        self.startDate = workout.startDate
        self.duration = workout.duration
        self.sourceName = workout.sourceRevision.source.name

        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning),
           let sum = workout.statistics(for: distanceType)?.sumQuantity() {
            self.distanceMiles = sum.doubleValue(for: .mile())
        } else if let cyclingType = HKQuantityType.quantityType(forIdentifier: .distanceCycling),
                  let sum = workout.statistics(for: cyclingType)?.sumQuantity() {
            self.distanceMiles = sum.doubleValue(for: .mile())
        } else {
            self.distanceMiles = nil
        }

        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let sum = workout.statistics(for: energyType)?.sumQuantity() {
            self.activeCalories = sum.doubleValue(for: .kilocalorie())
        } else {
            self.activeCalories = nil
        }
    }
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

    @Published private(set) var isAuthorized = false
    @Published private(set) var recentWorkouts: [CardioWorkout] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorizationAndFetch() async {
        guard isHealthDataAvailable else {
            errorMessage = "Health data isn't available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [workoutType])
            isAuthorized = true
            errorMessage = nil
            await fetchRecentWorkouts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchRecentWorkouts(limit: Int = 20) async {
        guard isHealthDataAvailable else { return }
        isLoading = true
        defer { isLoading = false }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        do {
            let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: workoutType, predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: samples ?? [])
                    }
                }
                store.execute(query)
            }
            recentWorkouts = samples.compactMap { $0 as? HKWorkout }.map(CardioWorkout.init)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
