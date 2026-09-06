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

    private func identifier(for module: TrackedModule, slotIndex: Int) -> String {
        "reminder.\(module.rawValue).\(slotIndex)"
    }

    /// Schedules every reminder slot defined for the module, replacing whatever was previously
    /// scheduled for it.
    func scheduleReminder(for module: TrackedModule) {
        cancelReminder(for: module)

        for (index, slot) in module.reminderSlots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = slot.title
            content.body = slot.body
            content.sound = .default

            var components = DateComponents()
            components.hour = slot.secondsFromMidnight / 3600
            components.minute = (slot.secondsFromMidnight % 3600) / 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier(for: module, slotIndex: index), content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelReminder(for module: TrackedModule) {
        let ids = module.reminderSlots.indices.map { identifier(for: module, slotIndex: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Re-arms any reminders the user has enabled. Call on launch so a reinstall or an OS-level
    /// permission change doesn't leave a stale toggle with nothing actually scheduled.
    func syncEnabledReminders() async {
        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        for module in TrackedModule.allCases {
            guard UserDefaults.standard.bool(forKey: ReminderPreferenceKeys.enabled(for: module)) else { continue }
            scheduleReminder(for: module)
        }
    }
}

/// One notification fired for a module's reminder — a module can have several (e.g. Nutrition's
/// three water check-ins throughout the day).
struct ReminderSlot {
    let secondsFromMidnight: Int
    let title: String
    let body: String
}

enum ReminderPreferenceKeys {
    static func enabled(for module: TrackedModule) -> String { "reminder.\(module.rawValue).enabled" }
}
