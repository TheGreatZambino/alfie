import Testing
@testable import Bruschetta

struct GoalStatusFormatterTests {
    @Test
    func statusThresholds() {
        #expect(GoalStatusFormatter.status(100) == "ahead")
        #expect(GoalStatusFormatter.status(90) == "ahead")
        #expect(GoalStatusFormatter.status(89.9) == "strong")
        #expect(GoalStatusFormatter.status(75) == "strong")
        #expect(GoalStatusFormatter.status(74.9) == "on pace")
        #expect(GoalStatusFormatter.status(55) == "on pace")
        #expect(GoalStatusFormatter.status(54.9) == "slipping")
        #expect(GoalStatusFormatter.status(35) == "slipping")
        #expect(GoalStatusFormatter.status(34.9) == "behind")
        #expect(GoalStatusFormatter.status(0) == "behind")
    }

    @Test
    func verdictThresholds() {
        #expect(GoalStatusFormatter.verdict(90) == "Outstanding week")
        #expect(GoalStatusFormatter.verdict(89.9) == "Strong week")
        #expect(GoalStatusFormatter.verdict(75) == "Strong week")
        #expect(GoalStatusFormatter.verdict(74.9) == "Good week so far")
        #expect(GoalStatusFormatter.verdict(55) == "Good week so far")
        #expect(GoalStatusFormatter.verdict(54.9) == "Slow week")
        #expect(GoalStatusFormatter.verdict(35) == "Slow week")
        #expect(GoalStatusFormatter.verdict(34.9) == "Rough week")
    }

    @Test
    func summaryReportsAllThreePillarsWhenAllTracked() {
        let summary = GoalStatusFormatter.summary(
            trackedModules: [.finance, .workouts, .nutrition],
            hasIncome: true,
            overallScore: 85,
            expenseScore: 90,
            remainingThisPeriod: 420,
            workoutScore: 60,
            strengthSessionsThisWeek: 2,
            strengthGoal: 3,
            calorieScore: 10,
            goodCalorieDays: 1,
            daysElapsedThisWeek: 5
        )

        #expect(summary == "You're having a strong week: Money is ahead with $420 left this period, Training is on pace with 2 of 3 sessions this week, Food is behind with 1 of 5 days on target.")
    }

    @Test
    func summaryOnlyMentionsTrackedPillars() {
        let summary = GoalStatusFormatter.summary(
            trackedModules: [.workouts],
            hasIncome: true,
            overallScore: 60,
            expenseScore: 100,
            remainingThisPeriod: 100,
            workoutScore: 60,
            strengthSessionsThisWeek: 2,
            strengthGoal: 3,
            calorieScore: 0,
            goodCalorieDays: 0,
            daysElapsedThisWeek: 5
        )

        #expect(summary.contains("Training is on pace"))
        #expect(!summary.contains("Money"))
        #expect(!summary.contains("Food"))
    }

    @Test
    func summaryFlagsFinanceWhenNoIncomeIsSetUp() {
        let summary = GoalStatusFormatter.summary(
            trackedModules: [.finance],
            hasIncome: false,
            overallScore: 0,
            expenseScore: 0,
            remainingThisPeriod: 0,
            workoutScore: 0,
            strengthSessionsThisWeek: 0,
            strengthGoal: 3,
            calorieScore: 0,
            goodCalorieDays: 0,
            daysElapsedThisWeek: 1
        )

        #expect(summary.contains("Money isn't set up yet"))
    }

    @Test
    func summaryHandlesNoTrackedModules() {
        let summary = GoalStatusFormatter.summary(
            trackedModules: [],
            hasIncome: false,
            overallScore: 0,
            expenseScore: 0,
            remainingThisPeriod: 0,
            workoutScore: 0,
            strengthSessionsThisWeek: 0,
            strengthGoal: 3,
            calorieScore: 0,
            goodCalorieDays: 0,
            daysElapsedThisWeek: 1
        )

        #expect(summary == "You're not tracking any goals yet — set those up in Alfie Track first.")
    }
}
