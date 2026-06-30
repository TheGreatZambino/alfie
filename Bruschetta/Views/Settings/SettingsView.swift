import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Income") {
                    NavigationLink("Income") {
                        IncomeSettingsView()
                    }
                }

                Section("Bills") {
                    NavigationLink("Bills") {
                        BillsSettingsView()
                    }
                }

                Section("Categories") {
                    NavigationLink("Categories") {
                        CategoriesSettingsView()
                    }
                }

                Section("About") {
                    Button("Re-run Onboarding") {
                        showOnboarding = true
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showOnboarding) {
                OnboardingView()
            }
        }
    }
}
