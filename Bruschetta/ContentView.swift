import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @Query private var categories: [Category]
    @Query private var exercises: [Exercise]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }

            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.bar.xaxis") }

            WorkoutView()
                .tabItem { Label("Workouts", systemImage: "figure.strengthtraining.traditional") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            OnboardingView()
        }
        .task {
            seedCategoriesIfNeeded()
            seedExercisesIfNeeded()
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
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
        guard exercises.isEmpty else { return }
        for seed in Exercise.starterExercises {
            modelContext.insert(Exercise(name: seed.name, muscleGroup: seed.muscleGroup))
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Income.self, Category.self, Bill.self, Transaction.self,
            Exercise.self, WorkoutTemplate.self, TemplateExerciseEntry.self, WorkoutSession.self, LoggedSet.self
        ], inMemory: true)
}
