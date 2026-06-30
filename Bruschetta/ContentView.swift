import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]
    @Query private var categories: [Category]

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selectedTab: Int = 0
    @State private var showAddTransaction = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house") }
                .tag(0)

            TransactionListView()
                .tabItem { Label("Transactions", systemImage: "list.bullet") }
                .tag(1)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)

            // Reserved stub slot for future Workout tab (hidden).
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showAddTransaction = true
                selectedTab = 0
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            AddTransactionView()
        }
        .sheet(isPresented: $showOnboarding, onDismiss: {
            hasCompletedOnboarding = true
        }) {
            OnboardingView()
        }
        .task {
            seedCategoriesIfNeeded()
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
}

#Preview {
    ContentView()
        .modelContainer(for: [Income.self, Category.self, Bill.self, Transaction.self], inMemory: true)
}
