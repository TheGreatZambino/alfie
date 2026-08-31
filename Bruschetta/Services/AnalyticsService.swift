import Foundation
import TelemetryDeck

/// Thin wrapper around TelemetryDeck. Every signal is anonymous (TelemetryDeck's default
/// device-derived identifier) — there's no user account to attach these to, so counts in
/// the dashboard are "distinct devices/installs," which is what we mean by "users" here.
enum AnalyticsService {
    enum WorkoutType: String {
        case strength
        case cardio
    }

    static func configure() {
        guard !Secrets.telemetryDeckAppID.isEmpty else { return }
        let config = TelemetryDeck.Config(appID: Secrets.telemetryDeckAppID)
        TelemetryDeck.initialize(config: config)
    }

    static func workoutLogged(_ type: WorkoutType) {
        TelemetryDeck.signal("workoutLogged", parameters: ["workoutType": type.rawValue])
    }

    static func transactionLogged() {
        TelemetryDeck.signal("transactionLogged")
    }

    /// Reports which weekly-goal-progress bracket the user currently falls in. Throttled to
    /// once per calendar day per device so repeated view refreshes don't spam duplicate signals.
    static func goalScoreBracket(_ score: Double) {
        let key = "analytics.lastGoalScoreSignalDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let lastSent = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(lastSent, inSameDayAs: today) {
            return
        }
        UserDefaults.standard.set(today, forKey: key)
        TelemetryDeck.signal("goalScore", parameters: ["bracket": bracketLabel(for: score)])
    }

    /// Reports that this device has at least one cardio workout synced this week. Throttled to
    /// once per calendar day since it's derived from a passive HealthKit read, not a user action.
    static func cardioWorkoutsPresent() {
        let key = "analytics.lastCardioSignalDate"
        let today = Calendar.current.startOfDay(for: Date())
        if let lastSent = UserDefaults.standard.object(forKey: key) as? Date,
           Calendar.current.isDate(lastSent, inSameDayAs: today) {
            return
        }
        UserDefaults.standard.set(today, forKey: key)
        workoutLogged(.cardio)
    }

    /// Reports a MetricKit crash or hang diagnostic. `detail` is a termination reason or
    /// hang duration only — never a stack trace or anything that could identify the user.
    static func diagnosticDetected(type: String, detail: String?) {
        var parameters = ["type": type]
        if let detail {
            parameters["detail"] = detail
        }
        TelemetryDeck.signal("diagnosticDetected", parameters: parameters)
    }

    static func bracketLabel(for score: Double) -> String {
        switch score {
        case ..<25: return "0-25"
        case 25..<50: return "25-50"
        case 50..<75: return "50-75"
        case 75..<90: return "75-90"
        default: return "90-100"
        }
    }
}
