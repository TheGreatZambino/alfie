import Combine
import SwiftUI
import SwiftData
import UIKit

struct LoggedDraftSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var durationSeconds: Int = 0
    var restSeconds: Int = 0
    var isLogged: Bool = false
}

struct LoggedDraftEntry: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var trackingType: TrackingType = .reps
    var sets: [LoggedDraftSet]

    var isComplete: Bool { sets.allSatisfy(\.isLogged) }
}

/// A saved copy of the running workout so it survives the app being killed. Exercises are stored by
/// identifier and looked up again on restore.
private struct WorkoutSnapshot: Codable {
    struct SetData: Codable {
        var reps: Int
        var weight: Double
        var durationSeconds: Int
        var restSeconds: Int
        var isLogged: Bool
    }
    struct EntryData: Codable {
        var exerciseID: PersistentIdentifier
        var trackingType: TrackingType
        var sets: [SetData]
    }
    var name: String
    var templateName: String?
    var templateID: PersistentIdentifier?
    var startTime: Date
    var restEndDate: Date?
    var restTotal: TimeInterval
    var planEntries: [EntryData]
    var draftEntries: [EntryData]
}

/// The in-progress workout. It lives outside `ActiveWorkoutView` so the workout, its elapsed time and
/// any rest countdown keep running while the screen is minimized or the app is in the background.
@MainActor
final class ActiveWorkoutSession: ObservableObject {
    static let shared = ActiveWorkoutSession()

    @Published private(set) var plan: WorkoutPlan?
    /// Whether the full-screen workout is showing; false while minimized to the mini bar.
    @Published var isPresented = false
    @Published var draftEntries: [LoggedDraftEntry] = []
    /// Set when the Live Activity skips ahead; otherwise focus is the first unfinished exercise.
    @Published var focusedEntryID: UUID?
    /// When set, a rest countdown is running and ends at this date.
    @Published var restEndDate: Date?
    /// Length of the current rest, for the banner's progress bar; grows when the user adds time.
    @Published var restTotal: TimeInterval = 0

    private(set) var startTime = Date()
    private var timer: Timer?
    private var liveActivityTask: Task<Void, Never>?
    private var lastLiveState: WorkoutActivityAttributes.ContentState?

    var isActive: Bool { plan != nil }

    var totalSets: Int { draftEntries.reduce(0) { $0 + $1.sets.count } }
    var completedSets: Int { draftEntries.reduce(0) { $0 + $1.sets.filter(\.isLogged).count } }

    /// Index of the exercise currently in focus — the first one with an unlogged set, unless the
    /// Live Activity skipped ahead.
    var currentExerciseIndex: Int? {
        if let focusedEntryID, let index = draftEntries.firstIndex(where: { $0.id == focusedEntryID && !$0.isComplete }) {
            return index
        }
        return draftEntries.firstIndex { !$0.isComplete }
    }

    private static let snapshotKey = "activeWorkoutSnapshot"
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Save shortly after any change (the change lands after `objectWillChange` fires).
        objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.persistNow() }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(forName: WorkoutLiveAction.notification, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated { self?.handleLiveAction(note) }
        }
    }

    // MARK: - Lifecycle

    /// Begins a workout and shows it full screen. Ignored if one is already running.
    func start(_ plan: WorkoutPlan) {
        guard self.plan == nil else {
            isPresented = true
            return
        }
        self.plan = plan
        startTime = Date()
        focusedEntryID = nil
        restEndDate = nil
        restTotal = 0
        draftEntries = plan.entries.map { entry in
            LoggedDraftEntry(exercise: entry.exercise, trackingType: entry.trackingType, sets: entry.sets.map {
                LoggedDraftSet(reps: $0.reps, weight: $0.weight, durationSeconds: $0.durationSeconds, restSeconds: $0.restSeconds)
            })
        }
        isPresented = true

        let state = liveActivityState
        lastLiveState = state
        WorkoutLiveActivityManager.shared.start(name: plan.name, startDate: startTime, state: state)
        startTicking()
        persistNow()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func minimize() { isPresented = false }
    func expand() { if isActive { isPresented = true } }

    /// Ends the workout without saving.
    func discard() {
        isPresented = false
        endWorkout()
    }

    /// Saves the workout as a `WorkoutSession` and ends it.
    func finish(context: ModelContext, updateTemplate: Bool = false) {
        guard let plan else { return }
        if updateTemplate { overwriteTemplate(plan: plan, context: context) }
        let elapsed = Date().timeIntervalSince(startTime)
        let session = WorkoutSession(date: startTime, name: plan.name, templateName: plan.templateName, durationSeconds: elapsed)
        context.insert(session)

        for entry in draftEntries {
            let priorBest = personalBest(for: entry.exercise, trackingType: entry.trackingType)
            var sessionBest = priorBest

            var loggedSets: [LoggedSet] = []
            for (index, draftSet) in entry.sets.enumerated() {
                let loggedSet = LoggedSet(exercise: entry.exercise, setNumber: index + 1, weight: draftSet.weight, reps: draftSet.reps, durationSeconds: draftSet.durationSeconds, trackingType: entry.trackingType)
                loggedSet.session = session
                context.insert(loggedSet)
                loggedSets.append(loggedSet)
                sessionBest = max(sessionBest, prValue(for: loggedSet))
            }

            guard sessionBest > priorBest else { continue }
            for loggedSet in loggedSets where !loggedSet.isWarmup && prValue(for: loggedSet) == sessionBest {
                loggedSet.isPR = true
            }
        }

        try? context.save()
        AnalyticsService.workoutLogged(.strength)
        isPresented = false
        endWorkout()
    }

    private func endWorkout() {
        timer?.invalidate()
        timer = nil
        restEndDate = nil
        RestTimerSoundPlayer.shared.endKeepAlive()
        WorkoutLiveActivityManager.shared.end()
        lastLiveState = nil
        plan = nil
        draftEntries = []
        focusedEntryID = nil
        UserDefaults.standard.removeObject(forKey: Self.snapshotKey)
    }

    // MARK: - Persistence

    /// Writes the running workout to disk. Also called when the app moves to the background.
    func persistNow() {
        guard let plan else { return }
        func entries(_ items: [(Exercise, TrackingType, [(Int, Double, Int, Int, Bool)])]) -> [WorkoutSnapshot.EntryData] {
            items.map { exercise, tracking, sets in
                .init(exerciseID: exercise.persistentModelID, trackingType: tracking, sets: sets.map {
                    .init(reps: $0.0, weight: $0.1, durationSeconds: $0.2, restSeconds: $0.3, isLogged: $0.4)
                })
            }
        }
        let snapshot = WorkoutSnapshot(
            name: plan.name,
            templateName: plan.templateName,
            templateID: plan.templateID,
            startTime: startTime,
            restEndDate: restEndDate,
            restTotal: restTotal,
            planEntries: entries(plan.entries.map { ($0.exercise, $0.trackingType, $0.sets.map { ($0.reps, $0.weight, $0.durationSeconds, $0.restSeconds, false) }) }),
            draftEntries: entries(draftEntries.map { ($0.exercise, $0.trackingType, $0.sets.map { ($0.reps, $0.weight, $0.durationSeconds, $0.restSeconds, $0.isLogged) }) })
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        }
    }

    /// Brings back a workout that was running when the app was killed, minimized so the user can
    /// resume or finish it. Call once at launch.
    func restoreIfNeeded() {
        guard plan == nil,
              let data = UserDefaults.standard.data(forKey: Self.snapshotKey),
              let snapshot = try? JSONDecoder().decode(WorkoutSnapshot.self, from: data) else { return }
        let context = AppModelContainer.shared.mainContext

        func exercise(_ id: PersistentIdentifier) -> Exercise? {
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.persistentModelID == id })
            return try? context.fetch(descriptor).first
        }
        let planEntries: [WorkoutPlanEntry] = snapshot.planEntries.compactMap { entry in
            guard let ex = exercise(entry.exerciseID) else { return nil }
            return WorkoutPlanEntry(exercise: ex, trackingType: entry.trackingType, sets: entry.sets.map {
                WorkoutPlanSet(reps: $0.reps, weight: $0.weight, durationSeconds: $0.durationSeconds, restSeconds: $0.restSeconds)
            })
        }
        let drafts: [LoggedDraftEntry] = snapshot.draftEntries.compactMap { entry in
            guard let ex = exercise(entry.exerciseID) else { return nil }
            return LoggedDraftEntry(exercise: ex, trackingType: entry.trackingType, sets: entry.sets.map {
                LoggedDraftSet(reps: $0.reps, weight: $0.weight, durationSeconds: $0.durationSeconds, restSeconds: $0.restSeconds, isLogged: $0.isLogged)
            })
        }

        plan = WorkoutPlan(name: snapshot.name, templateName: snapshot.templateName, templateID: snapshot.templateID, entries: planEntries)
        draftEntries = drafts
        startTime = snapshot.startTime
        restTotal = snapshot.restTotal
        // A rest that ran out while the app was closed is over; don't ring it late.
        restEndDate = snapshot.restEndDate.flatMap { $0 > Date() ? $0 : nil }
        isPresented = false
        if restEndDate != nil { RestTimerSoundPlayer.shared.beginKeepAlive() }

        let state = liveActivityState
        lastLiveState = state
        WorkoutLiveActivityManager.shared.start(name: snapshot.name, startDate: snapshot.startTime, state: state)
        startTicking()
    }

    // MARK: - Rest

    func startRest(_ seconds: Int) {
        restTotal = TimeInterval(seconds)
        setRestEnd(seconds > 0 ? Date().addingTimeInterval(TimeInterval(seconds)) : nil)
    }

    func adjustRest(by delta: Int) {
        guard let restEndDate else { return }
        let newEnd = restEndDate.addingTimeInterval(TimeInterval(delta))
        restTotal = max(1, restTotal + TimeInterval(delta))
        setRestEnd(newEnd > Date() ? newEnd : nil)
    }

    func skipRest() { setRestEnd(nil) }

    private func setRestEnd(_ date: Date?) {
        let wasResting = restEndDate != nil
        withAnimation(.snappy) { restEndDate = date }
        // The silent audio loop keeps the app alive in the background so the end-of-rest sound still plays.
        if date != nil, !wasResting {
            RestTimerSoundPlayer.shared.beginKeepAlive()
        } else if date == nil {
            RestTimerSoundPlayer.shared.endKeepAlive()
        }
        syncLiveActivity()
    }

    private func tick() {
        if let restEndDate, Date() >= restEndDate {
            setRestEnd(nil)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            RestTimerSoundPlayer.shared.playSelected()
        }
    }

    // MARK: - Live Activity

    var liveActivityState: WorkoutActivityAttributes.ContentState {
        guard let index = currentExerciseIndex,
              let setIndex = draftEntries[index].sets.firstIndex(where: { !$0.isLogged }) else {
            return .init(currentExercise: nil, setNumber: 0, setsInExercise: 0, weight: 0, effort: "", completedSets: completedSets, totalSets: totalSets, restEndDate: restEndDate)
        }
        let entry = draftEntries[index]
        let set = entry.sets[setIndex]
        return .init(
            currentExercise: entry.exercise.name,
            setNumber: setIndex + 1,
            setsInExercise: entry.sets.count,
            weight: set.weight,
            effort: entry.trackingType == .time ? durationLabel(set.durationSeconds) : "\(set.reps) reps",
            completedSets: completedSets,
            totalSets: totalSets,
            restEndDate: restEndDate
        )
    }

    /// Pushes the current state to the Live Activity once the pending edit has landed. Views call this
    /// after mutating `draftEntries`.
    func syncLiveActivity() {
        liveActivityTask?.cancel()
        liveActivityTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, self.isActive else { return }
            let state = self.liveActivityState
            guard state != self.lastLiveState else { return }
            self.lastLiveState = state
            WorkoutLiveActivityManager.shared.update(state)
        }
    }

    /// Applies a button tap from the Live Activity to the current set.
    private func handleLiveAction(_ note: Notification) {
        guard isActive,
              let raw = note.userInfo?["kind"] as? String,
              let kind = WorkoutLiveAction.Kind(rawValue: raw),
              let index = currentExerciseIndex else { return }
        switch kind {
        case .adjustWeight:
            guard let setIndex = draftEntries[index].sets.firstIndex(where: { !$0.isLogged }) else { return }
            let delta = note.userInfo?["delta"] as? Double ?? 0
            draftEntries[index].sets[setIndex].weight = max(0, draftEntries[index].sets[setIndex].weight + delta)
        case .logSet:
            guard let setIndex = draftEntries[index].sets.firstIndex(where: { !$0.isLogged }) else { return }
            draftEntries[index].sets[setIndex].isLogged = true
            startRest(draftEntries[index].sets[setIndex].restSeconds)
        case .nextExercise:
            let incomplete = draftEntries.indices.filter { !draftEntries[$0].isComplete }
            guard let next = incomplete.first(where: { $0 > index }) ?? incomplete.first(where: { $0 != index }) else { return }
            focusedEntryID = draftEntries[next].id
        }
        syncLiveActivity()
    }

    // MARK: - Saving helpers

    /// True when this workout started from a template and its exercises, sets or targets
    /// have since been edited.
    var planDiffersFromTemplate: Bool {
        guard let plan, plan.templateID != nil else { return false }
        func signature(_ sets: [(Int, Double, Int, Int)]) -> [[Int]] {
            sets.map { [$0.0, Int($0.1 * 100), $0.2, $0.3] }
        }
        let original = plan.entries.map { entry in
            [entry.exercise.id.hashValue, entry.trackingType.hashValue, signature(entry.sets.map { ($0.reps, $0.weight, $0.durationSeconds, $0.restSeconds) }).hashValue]
        }
        let current = draftEntries.map { entry in
            [entry.exercise.id.hashValue, entry.trackingType.hashValue, signature(entry.sets.map { ($0.reps, $0.weight, $0.durationSeconds, $0.restSeconds) }).hashValue]
        }
        return original != current
    }

    private func overwriteTemplate(plan: WorkoutPlan, context: ModelContext) {
        guard let id = plan.templateID, let template = context.model(for: id) as? WorkoutTemplate else { return }
        for entry in template.entries ?? [] {
            context.delete(entry)
        }
        for (index, entry) in draftEntries.enumerated() {
            let templateEntry = TemplateExerciseEntry(exercise: entry.exercise, order: index, trackingType: entry.trackingType)
            templateEntry.template = template
            context.insert(templateEntry)
            for (setIndex, set) in entry.sets.enumerated() {
                let setEntry = TemplateSetEntry(setNumber: setIndex + 1, targetReps: set.reps, targetWeight: set.weight, targetDurationSeconds: set.durationSeconds, restSeconds: set.restSeconds)
                setEntry.templateExercise = templateEntry
                context.insert(setEntry)
            }
        }
    }

    /// The value used to compare a set against the exercise's personal best: weight for
    /// rep-tracked sets, duration for time-tracked sets.
    private func prValue(for loggedSet: LoggedSet) -> Double {
        loggedSet.trackingType == .time ? Double(loggedSet.durationSeconds) : loggedSet.weight
    }

    /// The best value ever logged for this exercise (excluding warmups), before this session.
    private func personalBest(for exercise: Exercise, trackingType: TrackingType) -> Double {
        (exercise.loggedSets ?? [])
            .filter { $0.session != nil && !$0.isWarmup && $0.trackingType == trackingType }
            .map { $0.trackingType == .time ? Double($0.durationSeconds) : $0.weight }
            .max() ?? 0
    }
}

func durationLabel(_ totalSeconds: Int) -> String {
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    if minutes > 0 { return String(format: "%d:%02d", minutes, seconds) }
    return "\(seconds)s"
}
