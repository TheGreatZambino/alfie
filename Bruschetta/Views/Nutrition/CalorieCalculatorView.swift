import SwiftUI

enum CalorieCalcSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

/// Activity levels and BMR multipliers from NASM's calorie calculator guide.
/// Raw values are kept stable for existing @AppStorage selections.
enum CalorieCalcActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "low"
    case light = "light"
    case moderate = "medium"
    case veryActive = "high"
    case superActive = "super"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .superActive: return "Super Active"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Little to no exercise · BMR × 1.2"
        case .light: return "Light exercise/sports 1–3 days/week · BMR × 1.375"
        case .moderate: return "Moderate exercise/sports 3–5 days/week · BMR × 1.55"
        case .veryActive: return "Hard exercise/sports 6–7 days/week · BMR × 1.725"
        case .superActive: return "Very hard exercise & physical job or 2x training · BMR × 1.9"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .veryActive: return 1.725
        case .superActive: return 1.9
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
    @AppStorage("calorieCalc.activityLevel") private var activityLevel: CalorieCalcActivityLevel = .sedentary
    @AppStorage("calorieCalc.goal") private var goal: CalorieCalcGoal = .maintain

    /// Mifflin-St Jeor basal metabolic rate.
    private var bmr: Double {
        let weightKg = Double(weightPounds) * 0.45359237
        let heightCm = (Double(heightFeet) * 12 + Double(heightInches)) * 2.54
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    private var heightInchesTotal: Double { Double(heightFeet * 12 + heightInches) }

    /// BMI from pounds and inches.
    private var bmi: Double { Double(weightPounds) * 703 / (heightInchesTotal * heightInchesTotal) }

    private var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case ..<25: return "Healthy"
        case ..<30: return "Overweight"
        default: return "Obese"
        }
    }

    /// Weights (lb) for BMI 18.5 and 24.9 at the entered height.
    private var healthyRange: (low: Int, high: Int) {
        let squared = heightInchesTotal * heightInchesTotal
        return (Int((18.5 * squared / 703).rounded()), Int((24.9 * squared / 703).rounded()))
    }

    /// Devine ideal body weight (lb): 50 kg (male) or 45.5 kg (female) plus 2.3 kg per inch over 5 ft.
    private var idealWeight: Int {
        let kg = (sex == .male ? 50.0 : 45.5) + 2.3 * max(heightInchesTotal - 60, 0)
        return Int((kg / 0.45359237).rounded())
    }

    private var weightCheckFooter: String {
        if bmi >= 25, goal != .lose {
            return "Your weight is above the healthy range for your height. Choosing Lose Weight sets a calorie target for gradual loss."
        }
        if bmi < 18.5, goal != .gain {
            return "Your weight is below the healthy range for your height. Choosing Gain Weight sets a calorie target for gradual gain."
        }
        return "Based on your height and sex. BMI is a general screening measure and doesn't account for muscle mass."
    }

    private var maintenanceCalories: Double { bmr * activityLevel.multiplier }
    private var targetCalories: Double { maintenanceCalories + goal.calorieAdjustment }

    private func sourceRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .multilineTextAlignment(.leading)
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
        }
    }

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
                        Text("BMI")
                        Spacer()
                        Text(String(format: "%.1f · %@", bmi, bmiCategory))
                            .foregroundStyle(Color.inkSecondary)
                    }
                    HStack {
                        Text("Healthy Range")
                        Spacer()
                        Text("\(healthyRange.low)–\(healthyRange.high) lb")
                            .foregroundStyle(Color.inkSecondary)
                    }
                    HStack {
                        Text("Ideal Weight")
                        Spacer()
                        Text("\(idealWeight) lb")
                            .foregroundStyle(Color.inkSecondary)
                    }
                } header: {
                    Text("Weight Check")
                } footer: {
                    Text(weightCheckFooter)
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
                    Text("Estimated using the Mifflin-St Jeor formula. This is a starting point — adjust based on how your weight trends over a few weeks. This is not medical advice; consult a healthcare professional before changing your diet.")
                }

                Section {
                    Link(destination: URL(string: "https://www.nasm.org/resources/calorie-calculator")!) {
                        sourceRow(
                            title: "NASM: Calorie Calculator",
                            detail: "Mifflin-St Jeor BMR and activity multipliers"
                        )
                    }
                    Link(destination: URL(string: "https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html")!) {
                        sourceRow(
                            title: "CDC: Adult BMI Categories",
                            detail: "Healthy range (BMI 18.5–24.9) and weight categories"
                        )
                    }
                    Link(destination: URL(string: "https://en.wikipedia.org/wiki/Ideal_body_weight")!) {
                        sourceRow(
                            title: "Devine BR. Postgrad Med. 1974;40:A-95.",
                            detail: "Ideal weight by height and sex"
                        )
                    }
                } header: {
                    Text("Sources")
                }
            }
            .alfieListStyle()
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
