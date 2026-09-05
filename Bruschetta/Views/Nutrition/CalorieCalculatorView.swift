import SwiftUI

enum CalorieCalcSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

enum CalorieCalcActivityLevel: String, CaseIterable, Identifiable {
    case none
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var subtitle: String {
        switch self {
        case .none: return "Little to no exercise"
        case .low: return "1–3 workouts/week"
        case .medium: return "3–5 workouts/week"
        case .high: return "6–7 workouts/week"
        }
    }

    var multiplier: Double {
        switch self {
        case .none: return 1.2
        case .low: return 1.375
        case .medium: return 1.55
        case .high: return 1.725
        }
    }
}

enum CalorieCalcGoal: String, CaseIterable, Identifiable {
    case lose = "Lose Weight"
    case maintain = "Maintain Weight"
    case gain = "Gain Weight"

    var id: String { rawValue }

    /// Daily calorie adjustment from maintenance, roughly targeting 1 lb/week.
    var calorieAdjustment: Double {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 500
        }
    }
}

struct CalorieCalculatorView: View {
    @Environment(\.dismiss) private var dismiss

    let onApply: (Int) -> Void

    @AppStorage("calorieCalc.sex") private var sex: CalorieCalcSex = .male
    @AppStorage("calorieCalc.age") private var age = 30
    @AppStorage("calorieCalc.heightFeet") private var heightFeet = 5
    @AppStorage("calorieCalc.heightInches") private var heightInches = 8
    @AppStorage("calorieCalc.weightPounds") private var weightPounds = 160
    @AppStorage("calorieCalc.activityLevel") private var activityLevel: CalorieCalcActivityLevel = .low
    @AppStorage("calorieCalc.goal") private var goal: CalorieCalcGoal = .maintain

    /// Mifflin-St Jeor basal metabolic rate.
    private var bmr: Double {
        let weightKg = Double(weightPounds) * 0.45359237
        let heightCm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    private var maintenanceCalories: Double { bmr * activityLevel.multiplier }
    private var targetCalories: Double { maintenanceCalories + goal.calorieAdjustment }

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    Picker("Sex", selection: $sex) {
                        ForEach(CalorieCalcSex.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Stepper("Age: \(age)", value: $age, in: 13...100)
                    HStack {
                        Text("Height")
                        Spacer()
                        Picker("Feet", selection: $heightFeet) {
                            ForEach(3...7, id: \.self) { Text("\($0) ft").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        Picker("Inches", selection: $heightInches) {
                            ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    HStack {
                        Text("Current Weight")
                        Spacer()
                        TextField("lb", value: $weightPounds, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("lb")
                            .foregroundStyle(Color.inkTertiary)
                    }
                }

                Section {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(CalorieCalcActivityLevel.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Activity Level")
                } footer: {
                    Text(activityLevel.subtitle)
                }

                Section("Goal") {
                    Picker("Goal", selection: $goal) {
                        ForEach(CalorieCalcGoal.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Text("Maintenance")
                        Spacer()
                        Text("\(Int(maintenanceCalories.rounded())) cal/day")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    HStack {
                        Text(goal == .maintain ? "Your Goal" : "Your Goal (\(goal == .lose ? "−500" : "+500") cal)")
                        Spacer()
                        Text("\(Int(targetCalories.rounded())) cal/day")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.food)
                    }
                } header: {
                    Text("Result")
                } footer: {
                    Text("Estimated using the Mifflin-St Jeor formula. This is a starting point — adjust based on how your weight trends over a few weeks.")
                }
            }
            .navigationTitle("Calculate Calorie Intake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Goal") {
                        onApply(Int(targetCalories.rounded()))
                        dismiss()
                    }
                }
            }
        }
    }
}
