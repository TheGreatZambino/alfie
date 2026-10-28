import ActivityKit
import AppIntents
import Foundation

nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var currentExercise: String?
        /// 1-based position of the active set within the current exercise.
        var setNumber: Int
        var setsInExercise: Int
        var weight: Double
        /// "10 reps" or a duration label, depending on how the exercise is tracked.
        var effort: String
        var completedSets: Int
        var totalSets: Int
        /// When set, a rest countdown is running and ends at this date.
        var restEndDate: Date?
    }

    var workoutName: String
    var startDate: Date
}

nonisolated enum WorkoutLiveAction {
    static let notification = Notification.Name("WorkoutLiveActivityAction")
    static let weightStep: Double = 5

    enum Kind: String {
        case adjustWeight, logSet, nextExercise
    }

    static func post(_ kind: Kind, delta: Double = 0) {
        NotificationCenter.default.post(name: notification, object: nil, userInfo: ["kind": kind.rawValue, "delta": delta])
    }
}

// These run in the app's process (LiveActivityIntent) and are forwarded to the active workout screen.
struct AdjustWeightIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Adjust Weight"
    static let isDiscoverable = false

    @Parameter(title: "Change") var delta: Double

    init() {}
    init(delta: Double) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        WorkoutLiveAction.post(.adjustWeight, delta: delta)
        return .result()
    }
}

struct LogSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log Set"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        WorkoutLiveAction.post(.logSet)
        return .result()
    }
}

struct NextExerciseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Next Exercise"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        WorkoutLiveAction.post(.nextExercise)
        return .result()
    }
}
