import AppIntents
import SwiftData

/// Reads back the same weekly scores shown on the Overview screen — money, training, food —
/// so Siri can answer "how am I doing on my goals?" without opening the app.
struct GoalStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Goals"
    static var description = IntentDescription("Hear how you're tracking against your money, training, and food goals this week.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(AppModelContainer.shared)

        let trackedModulesRaw = UserDefaults.standard.string(forKey: TrackedModule.storageKey) ?? TrackedModule.defaultRawValue
        let trackedModules = TrackedModule.set(fromRawValue: trackedModulesRaw)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let workoutGoals = try context.fetch(FetchDescriptor<WorkoutGoals>()).first
        let incomes = try context.fetch(FetchDescriptor<Income>())
        let bills = try context.fetch(FetchDescriptor<Bill>())
        let savingsAccounts = try context.fetch(FetchDescriptor<SavingsAccount>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let nutritionEntries = try context.fetch(FetchDescriptor<NutritionEntry>())
        let nutritionGoal = try context.fetch(FetchDescriptor<NutritionGoals>()).first

        let viewModel = OverviewViewModel()
        viewModel.refresh(
            sessions: sessions,
            workoutGoals: workoutGoals,
            income: incomes.first,
            bills: bills,
            transactions: transactions,
            savingsAccounts: savingsAccounts,
            nutritionEntries: nutritionEntries,
            nutritionGoal: nutritionGoal,
            health: HealthKitManager.shared
        )
        await viewModel.waitForPendingRefresh()

        let dialog = GoalStatusFormatter.summary(
            trackedModules: trackedModules,
            hasIncome: incomes.first != nil,
            overallScore: viewModel.overallScore,
            expenseScore: viewModel.expenseScore,
            remainingThisPeriod: viewModel.remainingThisPeriod,
            workoutScore: viewModel.workoutScore,
            strengthSessionsThisWeek: viewModel.strengthSessionsThisWeek,
            strengthGoal: viewModel.strengthGoal,
            calorieScore: viewModel.calorieScore,
            goodCalorieDays: viewModel.goodCalorieDays,
            daysElapsedThisWeek: viewModel.daysElapsedThisWeek
        )
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }
}
