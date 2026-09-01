import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case overview
    case finances
    case workouts
    case nutrition

    var pillarColor: Color {
        switch self {
        case .overview: return .ink
        case .finances: return .money
        case .workouts: return .training
        case .nutrition: return .food
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @Query private var categories: [Category]
    @Query private var exercises: [Exercise]
    @Query private var nutritionGoals: [NutritionGoals]
    @Query private var workoutGoals: [WorkoutGoals]
    @Query private var savingsAccounts: [SavingsAccount]
    @Query private var bills: [Bill]
    @Query private var transactions: [Transaction]

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage(TrackedModule.storageKey) private var trackedModulesRaw = TrackedModule.defaultRawValue
    @State private var showOnboarding = false
    @State private var selectedTab: AppTab = .overview

    private var trackedModules: Set<TrackedModule> { TrackedModule.set(fromRawValue: trackedModulesRaw) }

    var body: some View {
        Group {
            if !authManager.isSignedIn {
                LoginView()
            } else {
                ZStack {
                    TabView(selection: $selectedTab) {
                        Tab("Overview", systemImage: selectedTab == .overview ? "house.fill" : "house", value: AppTab.overview) {
                            OverviewView(selectedTab: $selectedTab, trackedModules: trackedModules)
                        }

                        if trackedModules.contains(.finance) {
                            Tab("Finances", systemImage: selectedTab == .finances ? "wallet.bifold.fill" : "wallet.bifold", value: AppTab.finances) {
                                DashboardView()
                            }
                        }

                        if trackedModules.contains(.workouts) {
                            Tab("Workouts", systemImage: "figure.strengthtraining.traditional", value: AppTab.workouts) {
                                WorkoutView()
                            }
                        }

                        if trackedModules.contains(.nutrition) {
                            Tab("Nutrition", systemImage: "fork.knife", value: AppTab.nutrition) {
                                NutritionView()
                            }
                        }
                    }
                    .tint(selectedTab.pillarColor)
                    .onAppear { applyTabBarAppearance(for: selectedTab) }
                    .onChange(of: selectedTab) { _, newTab in applyTabBarAppearance(for: newTab) }
                    .onChange(of: trackedModulesRaw) { _, _ in
                        if selectedTab != .overview && !isTabVisible(selectedTab) {
                            selectedTab = .overview
                        }
                    }
                    .sheet(isPresented: $showOnboarding, onDismiss: {
                        hasCompletedOnboarding = true
                    }) {
                        OnboardingView()
                    }
                    .task {
                        seedCategoriesIfNeeded()
                        seedExercisesIfNeeded()
                        seedNutritionGoalsIfNeeded()
                        seedWorkoutGoalsIfNeeded()
                        seedSavingsAccountsIfNeeded()
                        SavingsReconciler.reconcile(income: incomes.first, bills: bills, transactions: transactions, savingsAccounts: savingsAccounts, context: modelContext)
                        if !hasCompletedOnboarding {
                            showOnboarding = true
                        }
                        await HealthKitManager.shared.requestAuthorizationAndFetch()
                        await NotificationManager.shared.syncEnabledReminders()
                    }
                    .disabled(!authManager.isUnlocked)

                    if !authManager.isUnlocked {
                        LockView()
                            .background(Color(.systemBackground))
                            .transition(.opacity)
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                authManager.lock()
            }
        }
    }

    private func isTabVisible(_ tab: AppTab) -> Bool {
        switch tab {
        case .overview: return true
        case .finances: return trackedModules.contains(.finance)
        case .workouts: return trackedModules.contains(.workouts)
        case .nutrition: return trackedModules.contains(.nutrition)
        }
    }

    private func seedCategoriesIfNeeded() {
        guard categories.isEmpty else { return }
        var sortOrder = 0
        for seed in Category.defaultSpendingCategories {
            let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .spending, sortOrder: sortOrder)
            modelContext.insert(category)
            sortOrder += 1
        }
        for seed in Category.defaultBillCategories {
            let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .bill, sortOrder: sortOrder)
            modelContext.insert(category)
            sortOrder += 1
        }
        try? modelContext.save()
    }

    private func seedExercisesIfNeeded() {
        let existingNames = Set(exercises.map { $0.name })
        var didInsert = false
        for seed in Exercise.starterExercises where !existingNames.contains(seed.name) {
            modelContext.insert(Exercise(name: seed.name, muscleGroup: seed.muscleGroup))
            didInsert = true
        }
        guard didInsert else { return }
        try? modelContext.save()
    }

    private func seedNutritionGoalsIfNeeded() {
        guard nutritionGoals.isEmpty else { return }
        modelContext.insert(NutritionGoals())
        try? modelContext.save()
    }

    private func seedWorkoutGoalsIfNeeded() {
        guard workoutGoals.isEmpty else { return }
        modelContext.insert(WorkoutGoals())
        try? modelContext.save()
    }

    private func seedSavingsAccountsIfNeeded() {
        guard savingsAccounts.isEmpty else { return }
        modelContext.insert(SavingsAccount(name: "Savings"))
        modelContext.insert(SavingsAccount(name: "Investments"))
        try? modelContext.save()
    }

    /// Paints the tab bar's selection pill in the current tab's pillar color and gives it a
    /// paper background with a hairline top border, per the design tokens.
    private func applyTabBarAppearance(for tab: AppTab) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.paper).withAlphaComponent(0.92)
        appearance.shadowColor = UIColor(Color(red: 35 / 255, green: 33 / 255, blue: 30 / 255).opacity(0.07))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(tab.pillarColor)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(tab.pillarColor),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.inkTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.inkTertiary),
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        appearance.selectionIndicatorTintColor = UIColor(tab.pillarColor).withAlphaComponent(0.12)
        appearance.selectionIndicatorImage = capsuleIndicatorImage()

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func capsuleIndicatorImage() -> UIImage {
        let size = CGSize(width: 52, height: 30)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 15)
            UIColor.white.setFill()
            path.fill()
        }.withRenderingMode(.alwaysTemplate)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
        .modelContainer(for: [
            Income.self, Category.self, Bill.self, Transaction.self, SavingsAccount.self,
            Exercise.self, WorkoutTemplate.self, TemplateExerciseEntry.self, TemplateSetEntry.self,
            WorkoutSession.self, LoggedSet.self, WorkoutGoals.self,
            FoodItem.self, NutritionEntry.self, NutritionGoals.self
        ], inMemory: true)
}
