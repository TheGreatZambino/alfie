import SwiftUI
import SwiftData

struct WorkoutGoalsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [WorkoutGoals]

    @State private var strengthGoal = 3
    @State private var cardioGoal = 2
    @State private var dailyStepGoal = 10000
    @State private var weeklyStepGoal = 70000

    var body: some View {
        Form {
            Section {
                Stepper("Strength sessions: \(strengthGoal)", value: $strengthGoal, in: 0...14)
                Stepper("Cardio sessions: \(cardioGoal)", value: $cardioGoal, in: 0...14)
            } header: {
                Text("Weekly Goals")
            } footer: {
                Text("Used to score your Workouts category on the Overview tab.")
            }

            Section {
                HStack {
                    Text("Daily steps")
                    Spacer()
                    TextField("Steps", value: $dailyStepGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .onChange(of: dailyStepGoal) { _, newValue in
                            dailyStepGoal = min(max(newValue, 0), 50000)
                        }
                }
                HStack {
                    Text("Weekly steps")
                    Spacer()
                    TextField("Steps", value: $weeklyStepGoal, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                        .onChange(of: weeklyStepGoal) { _, newValue in
                            weeklyStepGoal = min(max(newValue, 0), 350000)
                        }
                }
            } header: {
                Text("Step Goals")
            } footer: {
                Text("Daily goal shows on the Workouts tab; weekly goal is used on the Overview tab. Requires Apple Health access.")
            }
        }
        .navigationTitle("Workout Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        guard let goal = goals.first else { return }
        strengthGoal = goal.weeklyStrengthGoal
        cardioGoal = goal.weeklyCardioGoal
        dailyStepGoal = goal.dailyStepGoal
        weeklyStepGoal = goal.weeklyStepGoal
    }

    private func save() {
        let goal: WorkoutGoals
        if let existing = goals.first {
            goal = existing
        } else {
            goal = WorkoutGoals()
            modelContext.insert(goal)
        }
        goal.weeklyStrengthGoal = strengthGoal
        goal.weeklyCardioGoal = cardioGoal
        goal.dailyStepGoal = dailyStepGoal
        goal.weeklyStepGoal = weeklyStepGoal
        goal.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
