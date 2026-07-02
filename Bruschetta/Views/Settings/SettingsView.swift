import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            List {
                Section("Income") {
                    NavigationLink("Edit Income") {
                        IncomeSettingsView()
                    }
                }

                Section("Bills") {
                    NavigationLink("Edit Bills") {
                        BillsSettingsView()
                    }
                }

                Section("Categories") {
                    NavigationLink("Edit Categories") {
                        CategoriesSettingsView()
                    }
                }

                Section("Appearance") {
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: isDarkMode ? "moon.fill" : "sun.max.fill")
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
