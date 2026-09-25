import Foundation
import SwiftData
import UserNotifications

/// Wipes every trace of the current user so the next sign-in starts fresh, as if the app
/// were just installed: all SwiftData records, tracked-module/onboarding/appearance
/// preferences, per-module reminder toggles, and any pending local notifications.
enum DataResetService {
    @MainActor
    static func resetAllData(modelContext: ModelContext) {
        for model in AppSchema.models {
            try? modelContext.delete(model: model)
        }
        try? modelContext.save()

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "hasCompletedOnboarding")
        defaults.removeObject(forKey: TrackedModule.storageKey)
        defaults.removeObject(forKey: "appearanceMode")
        defaults.removeObject(forKey: "appLockEnabled")
        for module in TrackedModule.allCases {
            defaults.removeObject(forKey: ReminderPreferenceKeys.enabled(for: module))
        }
    }
}
