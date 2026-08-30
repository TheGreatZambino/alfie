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
