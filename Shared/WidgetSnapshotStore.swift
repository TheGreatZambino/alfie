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
    var updatedAt: Date? = nil
}

struct WaterSnapshot: Codable, Equatable {
    let ouncesToday: Double
    let goalOunces: Double
    var updatedAt: Date? = nil
}

struct WeekScoreSnapshot: Codable, Equatable {
    let score: Double
    let verdict: String
}

struct WidgetWorkoutSnapshot: Codable, Equatable {
    var strength: StrengthWorkoutSnapshot?
    var cardio: CardioWorkoutSnapshot?
    var finance: FinanceSnapshot?
    var nutrition: NutritionSnapshot?
    var water: WaterSnapshot?
    var weekScore: WeekScoreSnapshot?
}

extension WidgetWorkoutSnapshot {
    /// Daily slices (workouts, calories, water) are only meaningful for the day they were saved;
    /// if the app hasn't been opened since, show them empty. Finances and the week score persist.
    func resettingStaleDailyData(now: Date = Date(), calendar: Calendar = .current) -> WidgetWorkoutSnapshot {
        var result = self
        if let strength, !calendar.isDate(strength.date, inSameDayAs: now) { result.strength = nil }
        if let cardio, !calendar.isDate(cardio.date, inSameDayAs: now) { result.cardio = nil }
        if let n = nutrition, !calendar.isDate(n.updatedAt ?? .distantPast, inSameDayAs: now) {
            result.nutrition = NutritionSnapshot(caloriesToday: 0, calorieGoal: n.calorieGoal, updatedAt: now)
        }
        if let w = water, !calendar.isDate(w.updatedAt ?? .distantPast, inSameDayAs: now) {
            result.water = WaterSnapshot(ouncesToday: 0, goalOunces: w.goalOunces, updatedAt: now)
        }
        return result
    }
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
        return snapshot.resettingStaleDailyData()
    }
}
