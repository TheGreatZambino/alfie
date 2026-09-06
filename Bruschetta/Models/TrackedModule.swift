import Foundation

/// The optional pillars of the app a user can choose to track. Overview is always shown;
/// these gate the Finances/Workouts/Nutrition tabs and their related setup steps.
enum TrackedModule: String, CaseIterable, Identifiable, Hashable {
    case finance
    case workouts
    case nutrition

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .finance: return "Finance"
        case .workouts: return "Workouts"
        case .nutrition: return "Nutrition"
        }
    }

    var icon: String {
        switch self {
        case .finance: return "wallet.bifold.fill"
        case .workouts: return "figure.strengthtraining.traditional"
        case .nutrition: return "fork.knife"
        }
    }

    /// The daily reminder notification(s) for this module. Finance and Workouts fire once a day;
    /// Nutrition fires three times to nudge water intake throughout the day.
    var reminderSlots: [ReminderSlot] {
        switch self {
        case .finance:
            return [
                ReminderSlot(
                    secondsFromMidnight: 18 * 3600,
                    title: "Log today's spending",
                    body: "Keep your budget up to date — add any purchases from today."
                )
            ]
        case .workouts:
            return [
                ReminderSlot(
                    secondsFromMidnight: 6 * 3600,
                    title: "Rise and shine",
                    body: "Let's start the day with a workout!"
                )
            ]
        case .nutrition:
            return [
                ReminderSlot(secondsFromMidnight: 10 * 3600, title: "Stay hydrated", body: "Log your water intake and remember to drink up today."),
                ReminderSlot(secondsFromMidnight: 14 * 3600, title: "Stay hydrated", body: "How's your water intake looking? Log it and keep drinking."),
                ReminderSlot(secondsFromMidnight: 18 * 3600, title: "Stay hydrated", body: "Log today's water intake — and don't forget to drink more.")
            ]
        }
    }

    static let storageKey = "trackedModules"

    /// All modules, joined for the default @AppStorage value.
    static let defaultRawValue = allCases.map(\.rawValue).joined(separator: ",")

    static func set(fromRawValue rawValue: String) -> Set<TrackedModule> {
        let modules = rawValue
            .split(separator: ",")
            .compactMap { TrackedModule(rawValue: String($0)) }
        return modules.isEmpty ? Set(allCases) : Set(modules)
    }

    static func rawValue(from modules: Set<TrackedModule>) -> String {
        allCases.filter(modules.contains).map(\.rawValue).joined(separator: ",")
    }
}
