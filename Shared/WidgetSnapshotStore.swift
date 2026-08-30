import Foundation

struct StrengthWorkoutSnapshot: Codable, Equatable {
    let name: String
    let date: Date
    let totalVolume: Double
    let exerciseCount: Int
}

struct CardioWorkoutSnapshot: Codable, Equatable {
    let activityName: String
    let date: Date
    let durationMinutes: Int
    let distanceMiles: Double?
}

struct FinanceSnapshot: Codable, Equatable {
    let incomeThisPeriod: Double
    let remainingThisPeriod: Double
    let periodEnd: Date?
}

struct NutritionSnapshot: Codable, Equatable {
    let caloriesToday: Double
    let calorieGoal: Double
}

struct WidgetWorkoutSnapshot: Codable, Equatable {
    var strength: StrengthWorkoutSnapshot?
    var cardio: CardioWorkoutSnapshot?
    var finance: FinanceSnapshot?
    var nutrition: NutritionSnapshot?
}

/// Bridges today's workout/finance/nutrition summary from the main app (SwiftData + HealthKit)
/// to the widget extension, which can't query either of those directly.
enum WidgetSnapshotStore {
    static let appGroupID = "group.alfie.bruschetta"
    static let widgetKind = "AlfieTrackWidget"
    static let homeWidgetKind = "AlfieHomeWidget"
    private static let key = "widgetWorkoutSnapshot"

    static func save(_ snapshot: WidgetWorkoutSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Loads the current snapshot, applies `mutate`, and saves it back — so callers that
    /// only own one slice of the snapshot (e.g. finances) don't clobber the others.
    static func update(_ mutate: (inout WidgetWorkoutSnapshot) -> Void) {
        var snapshot = load()
        mutate(&snapshot)
        save(snapshot)
    }

    static func load() -> WidgetWorkoutSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetWorkoutSnapshot.self, from: data) else {
            return WidgetWorkoutSnapshot()
        }
        return snapshot
    }
}
