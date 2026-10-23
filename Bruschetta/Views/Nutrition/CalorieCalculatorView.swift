import SwiftUI

enum CalorieCalcSex: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

/// Lifestyle categories from FAO/WHO/UNU, Human energy requirements (2004), Table 5.3.
/// Raw values are kept stable for existing @AppStorage selections.
enum CalorieCalcActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "low"
    case active = "medium"
    case vigorous = "high"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary: return "Sedentary or Light"
        case .active: return "Active or Moderately Active"
        case .vigorous: return "Vigorous"
        }
    }

    var subtitle: String {
        switch self {
        case .sedentary: return "Little to light activity · PAL range 1.40–1.69"
        case .active: return "Regular moderate activity · PAL range 1.70–1.99"
        case .vigorous: return "Frequent intense activity · PAL range 2.00–2.40"
        }
    }

    /// Midpoint of the report's PAL range for the category.
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.55
        case .active: return 1.85
        case .vigorous: return 2.20
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
                Section {
                    Link(destination: URL(string: "https://doi.org/10.1093/ajcn/51.2.241")!) {
                        sourceRow(
                            title: "Mifflin MD, et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241–247.",
                            detail: "Basal metabolic rate formula"
                        )
                    }
                    Link(destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!) {
                        sourceRow(
                            title: "PubMed: Mifflin et al., 1990",
                            detail: "Abstract and citation record"
                        )
                    }
                    Link(destination: URL(string: "https://www.fao.org/4/Y5686E/y5686e00.htm")!) {
                        sourceRow(
                            title: "FAO/WHO/UNU. Human energy requirements: Report of a Joint Expert Consultation. FAO Food and Nutrition Technical Report Series 1. Rome, 2004.",
                            detail: "Physical activity level ranges (Table 5.3)"
                        )
                    }
                    Link(destination: URL(string: "https://www.mayoclinic.org/healthy-lifestyle/weight-loss/in-depth/weight-loss/art-20047752")!) {
                        sourceRow(
                            title: "Mayo Clinic: Weight loss — 6 strategies for success",
                            detail: "±500 cal/day adjustment for about 1 lb/week"
                        )
                    }
                } header: {
                    Text("Sources")
                } footer: {
                    Text("Total daily energy is estimated as BMR × physical activity level (PAL). Activity categories and PAL ranges are from Table 5.3 of the FAO/WHO/UNU report; the midpoint of each range is used.")
                }
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
                    Text("Estimated using the Mifflin-St Jeor formula. This is a starting point — adjust based on how your weight trends over a few weeks. This is not medical advice; consult a healthcare professional before changing your diet.")
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
