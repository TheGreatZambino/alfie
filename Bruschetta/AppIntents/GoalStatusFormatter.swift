import Foundation

/// Turns the Overview screen's computed scores into the sentence `GoalStatusIntent` hands
/// Siri. Kept free of `ModelContext`/`OverviewViewModel` so the phrasing and score
/// thresholds can be unit tested directly.
enum GoalStatusFormatter {
    static func summary(
        trackedModules: Set<TrackedModule>,
        hasIncome: Bool,
        overallScore: Double,
        expenseScore: Double,
        remainingThisPeriod: Double,
        workoutScore: Double,
        strengthSessionsThisWeek: Int,
        strengthGoal: Int,
        calorieScore: Double,
        goodCalorieDays: Int,
        daysElapsedThisWeek: Int
    ) -> String {
        guard !trackedModules.isEmpty else {
            return "You're not tracking any goals yet — set those up in Alfie Track first."
        }

        var pillars: [String] = []

        if trackedModules.contains(.finance) {
            if hasIncome {
                let remaining = remainingThisPeriod.formatted(.currency(code: "USD").precision(.fractionLength(0)))
                pillars.append("Money is \(status(expenseScore)) with \(remaining) left this period")
            } else {
                pillars.append("Money isn't set up yet")
            }
        }

        if trackedModules.contains(.workouts) {
            pillars.append("Training is \(status(workoutScore)) with \(strengthSessionsThisWeek) of \(strengthGoal) sessions this week")
        }

        if trackedModules.contains(.nutrition) {
            pillars.append("Food is \(status(calorieScore)) with \(goodCalorieDays) of \(daysElapsedThisWeek) days on target")
        }

        let pillarSummary = pillars.joined(separator: ", ")
        return "You're having a \(verdict(overallScore).lowercased()): \(pillarSummary)."
    }

    static func status(_ score: Double) -> String {
        switch score {
        case 80...: return "ahead"
        case 50..<80: return "on pace"
        default: return "behind"
        }
    }

    static func verdict(_ score: Double) -> String {
        switch score {
        case 80...: return "Strong week"
        case 50..<80: return "Good week so far"
        default: return "Slow week"
        }
    }
}
