import Testing
import Foundation
import SwiftData
@testable import Bruschetta

/// Covers `OverviewViewModel`'s scoring math — the numbers behind the Overview screen's
/// rings and, now, what `GoalStatusIntent` reads back to Siri. None of this touches
/// HealthKit: `HealthKitManager.shared` starts unauthorized in the test process, so
/// `refresh(...)` takes its synchronous path and cardio/step progress is always 0. That's
/// deterministic and exercised explicitly below rather than worked around.
@MainActor
struct OverviewViewModelTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Mirrors the private Monday-anchored week calculation `OverviewViewModel.refresh`
    /// uses internally, so calorie-score tests can build a full week of entries without
    /// depending on which weekday the test happens to run on.
    private func currentWeek() -> (start: Date, daysElapsed: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let mondayIndex = (weekday + 5) % 7
        let start = calendar.date(byAdding: .day, value: -mondayIndex, to: today) ?? today
        return (start, mondayIndex + 1)
    }

    private func refresh(
        _ viewModel: OverviewViewModel,
        sessions: [WorkoutSession] = [],
        workoutGoals: WorkoutGoals? = nil,
        income: Income? = nil,
        bills: [Bill] = [],
        transactions: [Transaction] = [],
        savingsAccounts: [SavingsAccount] = [],
        nutritionEntries: [NutritionEntry] = [],
        nutritionGoal: NutritionGoals? = nil
    ) {
        viewModel.refresh(
            sessions: sessions,
            workoutGoals: workoutGoals,
            income: income,
            bills: bills,
            transactions: transactions,
            savingsAccounts: savingsAccounts,
            nutritionEntries: nutritionEntries,
            nutritionGoal: nutritionGoal,
            health: HealthKitManager.shared
        )
    }

    // MARK: - Expense score

    @Test
    func expenseScorePerfectWhenRemainingIsPositive() throws {
        let context = try makeContext()
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: Date().addingTimeInterval(14 * 24 * 3600))
        let bill = Bill(name: "Rent", amount: 200, allocationAmount: 200, dueDay: 1)
        let transaction = Transaction(amount: 100, date: Date())
        context.insert(income)
        context.insert(bill)
        context.insert(transaction)

        let viewModel = OverviewViewModel()
        refresh(viewModel, income: income, bills: [bill], transactions: [transaction])

        // remaining = 1000 - 200 (bill) - 100 (spend) = 700, no overspend.
        #expect(viewModel.remainingThisPeriod == 700)
        #expect(viewModel.expenseScore == 100)
    }

    @Test
    func expenseScorePenalizesOverspend() throws {
        let context = try makeContext()
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: Date().addingTimeInterval(14 * 24 * 3600))
        let bill = Bill(name: "Rent", amount: 800, allocationAmount: 800, dueDay: 1)
        let transaction = Transaction(amount: 500, date: Date())
        context.insert(income)
        context.insert(bill)
        context.insert(transaction)

        let viewModel = OverviewViewModel()
        refresh(viewModel, income: income, bills: [bill], transactions: [transaction])

        // remaining = 1000 - 800 - 500 = -300; overspendFraction = min(1, 300/1000) = 0.3
        // score = (1 - 0.3) * 100 = 70
        #expect(viewModel.remainingThisPeriod == -300)
        #expect(viewModel.expenseScore == 70)
    }

    @Test
    func expenseScoreWeightsSavingsGoalAgainstEssentialOverspend() throws {
        let context = try makeContext()
        let savingsCategory = Category(name: "Savings", icon: "banknote.fill", colorHex: "#2E7D32", type: .bill, sortOrder: 0)
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: Date().addingTimeInterval(14 * 24 * 3600))
        let essentialBill = Bill(name: "Rent", amount: 900, allocationAmount: 900, dueDay: 1)
        let savingsBill = Bill(name: "Savings", amount: 50, allocationAmount: 50, dueDay: 1, category: savingsCategory)
        let transaction = Transaction(amount: 200, date: Date())
        context.insert(savingsCategory)
        context.insert(income)
        context.insert(essentialBill)
        context.insert(savingsBill)
        context.insert(transaction)

        let viewModel = OverviewViewModel()
        refresh(viewModel, income: income, bills: [essentialBill, savingsBill], transactions: [transaction])

        // essentialRemaining = 1000 - 900 (essential bill) - 200 (spend) = -100
        // essentialScore = (1 - min(1, 100/1000)) * 100 = 90
        // savingsScore = min(1, max(0, -100) / 50) * 100 = 0
        // expenseScore = 90 * 0.7 + 0 * 0.3 = 63
        #expect(abs(viewModel.expenseScore - 63) < 0.0001)
        // remaining = 1000 - 900 (essential) - 50 (savings) - 200 (spend) = -150
        #expect(viewModel.remainingThisPeriod == -150)
    }

    // MARK: - Workout score

    @Test
    func workoutScoreReflectsStrengthProgressOnlyWithoutHealthKit() throws {
        let context = try makeContext()
        let goals = WorkoutGoals(weeklyStrengthGoal: 3, weeklyCardioGoal: 2, dailyStepGoal: 10000, weeklyStepGoal: 70000)
        let sessions = (0..<3).map { _ in WorkoutSession(date: .now, name: "Push Day") }
        context.insert(goals)
        sessions.forEach(context.insert)

        let viewModel = OverviewViewModel()
        refresh(viewModel, sessions: sessions, workoutGoals: goals)

        // Strength goal fully met (progress 1); cardio and steps stay at 0 progress since
        // HealthKit is unauthorized in tests. workoutScore = (1 + 0 + 0) / 3 * 100.
        #expect(abs(viewModel.workoutScore - 100.0 / 3.0) < 0.0001)
    }

    @Test
    func workoutScoreCapsProgressWhenGoalIsExceeded() throws {
        let context = try makeContext()
        let goals = WorkoutGoals(weeklyStrengthGoal: 3, weeklyCardioGoal: 2, dailyStepGoal: 10000, weeklyStepGoal: 70000)
        let sessions = (0..<6).map { _ in WorkoutSession(date: .now, name: "Push Day") }
        context.insert(goals)
        sessions.forEach(context.insert)

        let viewModel = OverviewViewModel()
        refresh(viewModel, sessions: sessions, workoutGoals: goals)

        // Doubling the goal's worth of sessions shouldn't push progress past 1.
        #expect(abs(viewModel.workoutScore - 100.0 / 3.0) < 0.0001)
    }

    @Test
    func workoutScorePartialStrengthProgress() throws {
        let context = try makeContext()
        let goals = WorkoutGoals(weeklyStrengthGoal: 4, weeklyCardioGoal: 2, dailyStepGoal: 10000, weeklyStepGoal: 70000)
        let sessions = (0..<2).map { _ in WorkoutSession(date: .now, name: "Push Day") }
        context.insert(goals)
        sessions.forEach(context.insert)

        let viewModel = OverviewViewModel()
        refresh(viewModel, sessions: sessions, workoutGoals: goals)

        // strengthProgress = 2/4 = 0.5; workoutScore = (0.5 + 0 + 0) / 3 * 100
        #expect(abs(viewModel.workoutScore - 50.0 / 3.0) < 0.0001)
    }

    // MARK: - Calorie score

    @Test
    func calorieScorePerfectWhenEveryTrackedDayIsUnderGoal() throws {
        let context = try makeContext()
        let (weekStart, daysElapsed) = currentWeek()
        let goal = NutritionGoals(calorieGoal: 2000)
        let foodItem = FoodItem(name: "Salad", source: .custom, calories: 400)
        context.insert(goal)
        context.insert(foodItem)

        var entries: [NutritionEntry] = []
        for offset in 0..<daysElapsed {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!
            let entry = NutritionEntry(date: day, mealType: .lunch, quantity: 1, foodItem: foodItem)
            context.insert(entry)
            entries.append(entry)
        }

        let viewModel = OverviewViewModel()
        refresh(viewModel, nutritionEntries: entries, nutritionGoal: goal)

        #expect(viewModel.goodCalorieDays == daysElapsed)
        #expect(viewModel.trackedCalorieDays == daysElapsed)
        #expect(viewModel.calorieScore == 100)
    }

    @Test
    func calorieScoreZeroWhenEveryTrackedDayIsOverGoal() throws {
        let context = try makeContext()
        let (weekStart, daysElapsed) = currentWeek()
        let goal = NutritionGoals(calorieGoal: 1500)
        let foodItem = FoodItem(name: "Feast", source: .custom, calories: 2500)
        context.insert(goal)
        context.insert(foodItem)

        var entries: [NutritionEntry] = []
        for offset in 0..<daysElapsed {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!
            let entry = NutritionEntry(date: day, mealType: .dinner, quantity: 1, foodItem: foodItem)
            context.insert(entry)
            entries.append(entry)
        }

        let viewModel = OverviewViewModel()
        refresh(viewModel, nutritionEntries: entries, nutritionGoal: goal)

        #expect(viewModel.goodCalorieDays == 0)
        #expect(viewModel.calorieScore == 0)
    }

    // MARK: - Overall score

    @Test
    func overallScoreAveragesTheThreePillars() throws {
        let context = try makeContext()
        let (weekStart, daysElapsed) = currentWeek()

        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: Date().addingTimeInterval(14 * 24 * 3600))
        let bill = Bill(name: "Rent", amount: 200, allocationAmount: 200, dueDay: 1)
        let transaction = Transaction(amount: 100, date: Date())

        let workoutGoals = WorkoutGoals(weeklyStrengthGoal: 3, weeklyCardioGoal: 2, dailyStepGoal: 10000, weeklyStepGoal: 70000)
        let sessions = (0..<3).map { _ in WorkoutSession(date: .now, name: "Push Day") }

        let nutritionGoal = NutritionGoals(calorieGoal: 2000)
        let foodItem = FoodItem(name: "Salad", source: .custom, calories: 400)
        let entries = (0..<daysElapsed).map { offset -> NutritionEntry in
            let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart)!
            return NutritionEntry(date: day, mealType: .lunch, quantity: 1, foodItem: foodItem)
        }

        context.insert(income)
        context.insert(bill)
        context.insert(transaction)
        context.insert(workoutGoals)
        context.insert(nutritionGoal)
        context.insert(foodItem)
        sessions.forEach(context.insert)
        entries.forEach(context.insert)

        let viewModel = OverviewViewModel()
        refresh(
            viewModel,
            sessions: sessions,
            workoutGoals: workoutGoals,
            income: income,
            bills: [bill],
            transactions: [transaction],
            nutritionEntries: entries,
            nutritionGoal: nutritionGoal
        )

        // expenseScore = 100, workoutScore = 100/3, calorieScore = 100 (all set up above).
        let expected = (viewModel.workoutScore + viewModel.expenseScore + viewModel.calorieScore) / 3
        #expect(viewModel.overallScore == expected)
        #expect(abs(viewModel.overallScore - (100.0 + 100.0 / 3.0 + 100.0) / 3.0) < 0.0001)
    }
}
