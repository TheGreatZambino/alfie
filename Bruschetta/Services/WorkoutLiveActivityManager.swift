import ActivityKit
import Foundation

@MainActor
final class WorkoutLiveActivityManager {
    static let shared = WorkoutLiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?

    func start(name: String, startDate: Date, state: WorkoutActivityAttributes.ContentState) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = WorkoutActivityAttributes(workoutName: name, startDate: startDate)
        activity = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
