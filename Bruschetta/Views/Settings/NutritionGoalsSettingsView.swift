import SwiftUI
import SwiftData

struct NutritionGoalsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [NutritionGoals]

    @State private var calorieGoalText = ""
    @State private var proteinGoalText = ""
    @State private var carbsGoalText = ""
    @State private var fatGoalText = ""
    @State private var waterGoalText = ""
    @State private var isWaterTrackingEnabled = true
    @State private var showCalculator = false

    var body: some View {
        Form {
            Section("Daily Goals") {
                numberField("Calories", text: $calorieGoalText)
                numberField("Protein (g)", text: $proteinGoalText)
                numberField("Carbs (g)", text: $carbsGoalText)
                numberField("Fat (g)", text: $fatGoalText)
            }

            Section {
                Button {
                    showCalculator = true
                } label: {
                    Label("Calculate Maintenance Calories", systemImage: "function")
                }
            } footer: {
                Text("Estimate a daily calorie target based on your activity level and whether you want to maintain, lose, or gain weight.")
            }

            Section {
                Toggle("Track Water Intake", isOn: $isWaterTrackingEnabled)
                if isWaterTrackingEnabled {
                    numberField("Daily Goal (oz)", text: $waterGoalText)
                }
            } header: {
                Text("Water Intake")
            } footer: {
                Text("The recommended daily intake is about 64 oz (eight 8 oz glasses). Turn tracking off to hide water from your nutrition screen.")
            }
        }
        .sheet(isPresented: $showCalculator) {
            CalorieCalculatorView { calories in
                calorieGoalText = String(calories)
            }
        }
        .navigationTitle("Nutrition Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear { load() }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    private func load() {
        guard let goal = goals.first else { return }
        calorieGoalText = String(format: "%.0f", goal.calorieGoal)
        proteinGoalText = String(format: "%.0f", goal.proteinGoalGrams)
        carbsGoalText = String(format: "%.0f", goal.carbsGoalGrams)
        fatGoalText = String(format: "%.0f", goal.fatGoalGrams)
        waterGoalText = String(format: "%.0f", goal.waterGoalOunces)
        isWaterTrackingEnabled = goal.isWaterTrackingEnabled
    }

    private func save() {
        let goal: NutritionGoals
        if let existing = goals.first {
            goal = existing
        } else {
            goal = NutritionGoals()
            modelContext.insert(goal)
        }
        goal.calorieGoal = Double(calorieGoalText) ?? goal.calorieGoal
        goal.proteinGoalGrams = Double(proteinGoalText) ?? goal.proteinGoalGrams
        goal.carbsGoalGrams = Double(carbsGoalText) ?? goal.carbsGoalGrams
        goal.fatGoalGrams = Double(fatGoalText) ?? goal.fatGoalGrams
        goal.waterGoalOunces = Double(waterGoalText) ?? goal.waterGoalOunces
        goal.isWaterTrackingEnabled = isWaterTrackingEnabled
        goal.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
