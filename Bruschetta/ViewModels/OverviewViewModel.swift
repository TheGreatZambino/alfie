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

            let historicalRatios = Self.historicalEssentialRatios(
                income: income,
                essentialBillAllocation: essentialBillAllocation,
                transactions: transactions
            )
            expenseScore = Self.expenseScore(
                essentialRemaining: incomeThisPeriod - essentialBillAllocation - spending,
                income: incomeThisPeriod,
                savingsGoal: savingsAllocation,
                historicalRatios: historicalRatios
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

    /// How many completed pay periods of transaction history are needed before scoring switches
    /// from the fixed cold-start curve to the user's own historical baseline.
    private static let minHistoricalPeriodsForBaseline = 3
    private static let historicalPeriodsToConsider = 6

    /// Scores expense management on two things: staying within essential bills and spending
    /// (not counting money set aside for savings/investing) relative to the user's own recent
    /// history, and separately hitting the savings goal. Allocating money to savings shouldn't
    /// drag the score down the same way overspending on real expenses does.
    ///
    /// Rather than a fixed "target buffer" percentage (which varies wildly by person), the
    /// essential-spending score is calibrated against the user's own trailing pay periods: a
    /// period in line with their own average lands around 50, better-than-usual periods climb
    /// toward 100, and worse-than-usual periods fall toward 0. This self-calibrates to income
    /// level and spending habits without asking the user to configure anything. Until there's
    /// enough history to establish a baseline, it falls back to a simple non-negative-balance
    /// curve.
    private static func balanceScore(remaining: Double, income: Double, historicalRatios: [Double]) -> Double {
        guard income > 0 else { return remaining >= 0 ? 100 : 0 }
        let ratio = remaining / income

        guard historicalRatios.count >= minHistoricalPeriodsForBaseline else {
            guard ratio < 0 else { return 100 }
            return max(0, (1 + ratio) * 100)
        }

        let mean = historicalRatios.reduce(0, +) / Double(historicalRatios.count)
        let variance = historicalRatios.reduce(0) { $0 + pow($1 - mean, 2) } / Double(historicalRatios.count)
        // Floor stdDev so a run of nearly-identical past periods doesn't make the score
        // hypersensitive to tiny fluctuations this period.
        let stdDev = max(sqrt(variance), 0.02)
        let z = max(-3, min(3, (ratio - mean) / stdDev))
        return 50 + (z / 3) * 50
    }

    private static func expenseScore(essentialRemaining: Double, income: Double, savingsGoal: Double, historicalRatios: [Double]) -> Double {
        let essentialScore = balanceScore(remaining: essentialRemaining, income: income, historicalRatios: historicalRatios)
        guard savingsGoal > 0 else { return essentialScore }
        let savingsScore = min(1, max(0, essentialRemaining) / savingsGoal) * 100
        return essentialScore * 0.7 + savingsScore * 0.3
    }

    /// Builds the trailing essential-remaining/income ratios used to calibrate `balanceScore`,
    /// using the same essential-bill allocation as the current period (bill allocations are
    /// treated as roughly stable) applied to each prior period's actual transactions. Periods
    /// with no recorded transactions are skipped rather than counted as a perfect $0-spend period.
    private static func historicalEssentialRatios(
        income: Income,
        essentialBillAllocation: Double,
        transactions: [Transaction]
    ) -> [Double] {
        guard income.amountPerPeriod > 0 else { return [] }
        let periods = PayPeriodCalculator.previousPayPeriods(
            nextPayDate: income.nextPayDate,
            cadence: income.cadence,
            count: historicalPeriodsToConsider
        )
        return periods.compactMap { period -> Double? in
            let periodTransactions = transactions.filter {
                $0.date >= period.start && $0.date <= period.end && $0.category?.includeInOverview != false
            }
            guard !periodTransactions.isEmpty else { return nil }
            let spending = periodTransactions.reduce(0) { $0 + $1.amount }
            let remaining = income.amountPerPeriod - essentialBillAllocation - spending
            return remaining / income.amountPerPeriod
        }
    }
}
