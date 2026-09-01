import Combine
import Foundation
import UserNotifications

/// Schedules local daily reminder notifications for the tracked modules (Finance, Workouts,
/// Nutrition). Each module's reminder is opt-in and independently configurable; enabling one
/// requests notification permission the first time it's needed.
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Requests permission only if it hasn't been decided yet; otherwise reports the existing
    /// (possibly denied) status so callers can point the user at Settings instead of re-prompting.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationStatus = settings.authorizationStatus
            return true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            await refreshAuthorizationStatus()
            return granted
        case .denied:
            authorizationStatus = .denied
            return false
        @unknown default:
            return false
        }
    }

    private func identifier(for module: TrackedModule) -> String {
        "reminder.\(module.rawValue).daily"
    }

    func scheduleReminder(for module: TrackedModule, atSecondsFromMidnight seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: module)
        content.body = reminderBody(for: module)
        content.sound = .default

        var components = DateComponents()
        components.hour = seconds / 3600
        components.minute = (seconds % 3600) / 60

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier(for: module), content: content, trigger: trigger)

        let id = identifier(for: module)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request)
    }

    func cancelReminder(for module: TrackedModule) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: module)])
    }

    /// Re-arms any reminders the user has enabled. Call on launch so a reinstall or an OS-level
    /// permission change doesn't leave a stale toggle with nothing actually scheduled.
    func syncEnabledReminders() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        for module in TrackedModule.allCases {
            guard UserDefaults.standard.bool(forKey: ReminderPreferenceKeys.enabled(for: module)) else { continue }
            let seconds = UserDefaults.standard.object(forKey: ReminderPreferenceKeys.timeSeconds(for: module)) as? Int
                ?? module.defaultReminderSeconds
            scheduleReminder(for: module, atSecondsFromMidnight: seconds)
        }
    }

    private func reminderTitle(for module: TrackedModule) -> String {
        switch module {
        case .finance: return "Log today's spending"
        case .workouts: return "Time to move"
        case .nutrition: return "Log your meals"
        }
    }

    private func reminderBody(for module: TrackedModule) -> String {
        switch module {
        case .finance: return "Keep your budget up to date — add any transactions from today."
        case .workouts: return "Don't forget to log today's workout in Alfie Track."
        case .nutrition: return "Add what you've eaten today to stay on top of your goals."
        }
    }
}

enum ReminderPreferenceKeys {
    static func enabled(for module: TrackedModule) -> String { "reminder.\(module.rawValue).enabled" }
    static func timeSeconds(for module: TrackedModule) -> String { "reminder.\(module.rawValue).timeSeconds" }
}
