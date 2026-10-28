import SwiftUI
import SwiftData

struct WorkoutGoalsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [WorkoutGoals]

    @AppStorage(RestTimerSound.storageKey) private var restSound = RestTimerSound.boxingBell

    @State private var strengthGoal = 3
    @State private var cardioGoal = 2
    @State private var dailyStepGoal = 10000
    @State private var weeklyStepGoal = 70000
    @State private var weeklyMileGoal = 0.0
    @State private var monthlyMileGoal = 0.0
    @State private var averageDailyMileGoal = 0.0

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

            Section {
                mileRow("Weekly miles", value: $weeklyMileGoal, max: 500)
                mileRow("Monthly miles", value: $monthlyMileGoal, max: 2000)
                mileRow("Average daily miles", value: $averageDailyMileGoal, max: 100)
            } header: {
                Text("Mile Goals")
            } footer: {
                Text("Miles come from your Apple Health workouts. Average daily miles is this week's total divided by days elapsed. Goals set to 0 are left out of your Workouts score.")
            }

            Section {
                Picker("Sound", selection: $restSound) {
                    ForEach(RestTimerSound.allCases) { sound in
                        Text(sound.label).tag(sound)
                    }
                }
                .onChange(of: restSound) { _, sound in
                    RestTimerSoundPlayer.shared.play(sound)
                }
            } header: {
                Text("Rest Timer")
            } footer: {
                Text("Plays when a rest timer ends during a workout. Also plays when your phone is locked or the app is in the background, and over the silent switch. Mixes with your music and plays through headphones.")
            }
        }
        .alfieListStyle()
        .navigationTitle("Workout Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear { load() }
    }

    private func mileRow(_ title: String, value: Binding<Double>, max upper: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(Swift.max(newValue, 0), upper)
                }
        }
    }

    private func load() {
        guard let goal = goals.first else { return }
        strengthGoal = goal.weeklyStrengthGoal
        cardioGoal = goal.weeklyCardioGoal
        dailyStepGoal = goal.dailyStepGoal
        weeklyStepGoal = goal.weeklyStepGoal
        weeklyMileGoal = goal.weeklyMileGoal
        monthlyMileGoal = goal.monthlyMileGoal
        averageDailyMileGoal = goal.averageDailyMileGoal
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
        goal.weeklyMileGoal = weeklyMileGoal
        goal.monthlyMileGoal = monthlyMileGoal
        goal.averageDailyMileGoal = averageDailyMileGoal
        goal.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }
}
