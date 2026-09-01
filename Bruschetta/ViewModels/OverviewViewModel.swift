import Foundation
import SwiftData
import Combine

/// Whether the user did a strength and/or cardio session on a given day, for the Overview
/// week-grid visualization.
struct DayCompletion: Identifiable {
    let date: Date
    let hasStrength: Bool
    let hasCardio: Bool
    var id: Date { date }
}

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var daysElapsedThisWeek: Int = 1

    @Published var strengthSessionsThisWeek: Int = 0
    @Published var cardioSessionsThisWeek: Int = 0
    @Published var strengthGoal: Int = 3
    @Published var cardioGoal: Int = 2
    @Published var isLoadingCardio: Bool = false
    @Published var workoutScore: Double = 0
    @Published var weekdayCompletion: [DayCompletion] = []

    @Published var stepsThisWeek: Int = 0
    @Published var weeklyStepGoal: Int = 70000
    @Published var isLoadingSteps: Bool = false

    @Published var incomeThisPeriod: Double = 0
    @Published var remainingThisPeriod: Double = 0
    @Published var billsAllocationThisPeriod: Double = 0
    @Published var savingsAllocationThisPeriod: Double = 0
    @Published var spendingThisPeriod: Double = 0
    @Published var expenseScore: Double = 0

    @Published var calorieGoal: Double = 2000
    @Published var goodCalorieDays: Int = 0
    @Published var trackedCalorieDays: Int = 0
    @Published var calorieScore: Double = 0

    @Published var overallScore: Double = 0

    private var cardioTask: Task<Void, Never>?
    private var weekStart: Date = Date()

    /// Waits for any in-flight HealthKit fetch kicked off by `refresh(...)` to finish, so
    /// callers that need the fully computed scores (e.g. a Siri intent) don't read stale
    /// workout/step data. The Overview screen itself doesn't need this — it just observes
    /// `@Published` updates as they land.
    func waitForPendingRefresh() async {
        await cardioTask?.value
    }

    func refresh(
        sessions: [WorkoutSession],
        workoutGoals: WorkoutGoals?,
        income: Income?,
        bills: [Bill],
        transactions: [Transaction],
        savingsAccounts: [SavingsAccount] = [],
        nutritionEntries: [NutritionEntry],
        nutritionGoal: NutritionGoals?,
        health: HealthKitManager
    ) {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        // weekday: 1 = Sunday ... 7 = Saturday (Gregorian, independent of firstWeekday).
        // Convert to a Monday-anchored index: 0 = Monday ... 6 = Sunday.
        let weekday = calendar.component(.weekday, from: today)
        let mondayIndex = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -mondayIndex, to: today) ?? today
        daysElapsedThisWeek = mondayIndex + 1
        weekStart = start

        strengthGoal = workoutGoals?.weeklyStrengthGoal ?? 3
        cardioGoal = workoutGoals?.weeklyCardioGoal ?? 2
        weeklyStepGoal = workoutGoals?.weeklyStepGoal ?? 70000
        let weekSessions = sessions.filter { $0.date >= start && $0.date <= now }
        strengthSessionsThisWeek = weekSessions.count
        cardioSessionsThisWeek = 0
        recomputeWorkoutScore()
        rebuildWeekdayCompletion(strengthDates: weekSessions.map(\.date), cardioDates: [])

        if let income {
            let period = PayPeriodCalculator.currentPayPeriod(nextPayDate: income.nextPayDate, cadence: income.cadence)
            let activeBills = bills.filter { $0.isActive && $0.category?.includeInOverview != false }
            let essentialBills = activeBills.filter { $0.category?.isSavingsOrInvesting != true }
            let essentialBillAllocation = essentialBills.reduce(0) { $0 + $1.allocationAmount }
            let savingsAccountAllocation = savingsAccounts.reduce(0) { $0 + $1.allocationPerPaycheck }
            let savingsAllocation = activeBills
                .filter { $0.category?.isSavingsOrInvesting == true }
                .reduce(0) { $0 + $1.allocationAmount } + savingsAccountAllocation
            let periodTransactions = transactions.filter {
                $0.date >= period.start && $0.date <= period.end && $0.category?.includeInOverview != false
            }
            let spending = periodTransactions.reduce(0) { $0 + $1.amount }
            incomeThisPeriod = income.amountPerPeriod
            billsAllocationThisPeriod = essentialBillAllocation
            savingsAllocationThisPeriod = savingsAllocation
            spendingThisPeriod = spending
            remainingThisPeriod = incomeThisPeriod - essentialBillAllocation - savingsAllocation - spending
            expenseScore = Self.expenseScore(
                essentialRemaining: incomeThisPeriod - essentialBillAllocation - spending,
                income: incomeThisPeriod,
                savingsGoal: savingsAllocation
            )
        } else {
            incomeThisPeriod = 0
            remainingThisPeriod = 0
            billsAllocationThisPeriod = 0
            savingsAllocationThisPeriod = 0
            spendingThisPeriod = 0
            expenseScore = 0
        }

        calorieGoal = nutritionGoal?.calorieGoal ?? 2000
        var goodDays = 0
        var trackedDays = 0
        var day = start
        while day <= today {
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let entriesForDay = nutritionEntries.filter { $0.date >= day && $0.date < nextDay }
            if !entriesForDay.isEmpty {
                trackedDays += 1
                let total = entriesForDay.reduce(0) { $0 + $1.calories }
                if total <= calorieGoal {
                    goodDays += 1
                }
            }
            day = nextDay
        }
        goodCalorieDays = goodDays
        trackedCalorieDays = trackedDays
        calorieScore = (Double(goodDays) / Double(daysElapsedThisWeek)) * 100

        recomputeOverallScore()

        cardioTask?.cancel()
        guard health.isHealthDataAvailable, health.isAuthorized else {
            AnalyticsService.goalScoreBracket(overallScore)
            return
        }
        isLoadingCardio = true
        isLoadingSteps = true
        cardioTask = Task { [weak self] in
            guard let self else { return }
            async let workoutsFetch = health.fetchWorkouts(in: DateInterval(start: start, end: now))
            async let stepsFetch = health.fetchStepCount(in: DateInterval(start: start, end: now))
            let (workouts, steps) = await (workoutsFetch, stepsFetch)
            guard !Task.isCancelled else { return }
            self.cardioSessionsThisWeek = workouts.count
            self.stepsThisWeek = steps
            self.isLoadingCardio = false
            self.isLoadingSteps = false
            self.recomputeWorkoutScore()
            self.recomputeOverallScore()
            self.rebuildWeekdayCompletion(strengthDates: sessions.filter { $0.date >= self.weekStart && $0.date <= now }.map(\.date), cardioDates: workouts.map(\.startDate))
            AnalyticsService.goalScoreBracket(self.overallScore)
            if workouts.count > 0 {
                AnalyticsService.cardioWorkoutsPresent()
            }
        }
    }

    /// Builds a Mon–Sun completion grid from raw session/workout dates, for the Overview
    /// training week visualization.
    private func rebuildWeekdayCompletion(strengthDates: [Date], cardioDates: [Date]) {
        let calendar = Calendar.current
        let strengthDays = Set(strengthDates.map { calendar.startOfDay(for: $0) })
        let cardioDays = Set(cardioDates.map { calendar.startOfDay(for: $0) })
        weekdayCompletion = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return DayCompletion(date: day, hasStrength: strengthDays.contains(day), hasCardio: cardioDays.contains(day))
        }
    }

    private func recomputeWorkoutScore() {
        let strengthProgress = strengthGoal > 0 ? min(1, Double(strengthSessionsThisWeek) / Double(strengthGoal)) : 1
        let cardioProgress = cardioGoal > 0 ? min(1, Double(cardioSessionsThisWeek) / Double(cardioGoal)) : 1
        let stepsProgress = weeklyStepGoal > 0 ? min(1, Double(stepsThisWeek) / Double(weeklyStepGoal)) : 1
        workoutScore = (strengthProgress + cardioProgress + stepsProgress) / 3 * 100
    }

    private func recomputeOverallScore() {
        overallScore = (workoutScore + expenseScore + calorieScore) / 3
    }

    /// Scores expense management on two things: staying in the black on essential bills and
    /// spending (not counting money set aside for savings/investing), and separately hitting
    /// the savings goal. Allocating money to savings shouldn't drag the score down the same way
    /// overspending on real expenses does.
    private static func balanceScore(remaining: Double, income: Double) -> Double {
        guard remaining < 0 else { return 100 }
        guard income > 0 else { return 0 }
        let overspendFraction = min(1, -remaining / income)
        return max(0, (1 - overspendFraction) * 100)
    }

    private static func expenseScore(essentialRemaining: Double, income: Double, savingsGoal: Double) -> Double {
        let essentialScore = balanceScore(remaining: essentialRemaining, income: income)
        guard savingsGoal > 0 else { return essentialScore }
        let savingsScore = min(1, max(0, essentialRemaining) / savingsGoal) * 100
        return essentialScore * 0.7 + savingsScore * 0.3
    }
}
