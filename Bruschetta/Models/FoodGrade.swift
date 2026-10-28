import SwiftUI

/// A Nutri-Score style letter grade, A (best) through E (worst).
enum FoodGrade: Int, CaseIterable, Comparable {
    case e = 1, d, c, b, a

    var letter: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        }
    }

    var color: Color {
        switch self {
        case .a: return Color(hex: "#2E9E5B")
        case .b: return Color(hex: "#85BB2F")
        case .c: return Color(hex: "#E8B500")
        case .d: return Color(hex: "#EE8100")
        case .e: return Color(hex: "#E63E11")
        }
    }

    /// Credit toward the daily nutrition score, 0...1. Weighted so an average C day still
    /// earns most of the food-quality half, while D and E fall off sharply.
    var scorePoints: Double {
        switch self {
        case .a: return 1
        case .b: return 0.85
        case .c: return 0.7
        case .d: return 0.35
        case .e: return 0
        }
    }

    init?(nutriScore: String?) {
        switch nutriScore?.lowercased() {
        case "a": self = .a
        case "b": self = .b
        case "c": self = .c
        case "d": self = .d
        case "e": self = .e
        default: return nil
        }
    }

    static func < (lhs: FoodGrade, rhs: FoodGrade) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Rounds an average of grade points (A = 5 … E = 1) back to a letter.
    init(averagePoints: Double) {
        self = FoodGrade(rawValue: min(5, max(1, Int(averagePoints.rounded())))) ?? .c
    }

    /// Simplified Nutri-Score for foods lacking an official grade. Takes per-100g values.
    /// Saturated fat and fruit/veg content aren't tracked, so total fat (at 40%) stands in
    /// for saturated fat and the fruit/veg bonus is skipped. A lean-protein bonus offsets that.
    static func estimate(caloriesPer100g: Double, sugarPer100g: Double, fatPer100g: Double,
                         sodiumMgPer100g: Double, fiberPer100g: Double, proteinPer100g: Double) -> FoodGrade {
        func points(_ value: Double, step: Double, cap: Int) -> Int {
            min(cap, max(0, Int((value / step).rounded(.down))))
        }
        let negative = points(caloriesPer100g * 4.184, step: 335, cap: 10)
            + points(sugarPer100g, step: 4.5, cap: 10)
            + points(fatPer100g * 0.4, step: 1, cap: 10)
            + points(sodiumMgPer100g, step: 90, cap: 10)
        let positive = points(fiberPer100g, step: 0.9, cap: 5) + points(proteinPer100g, step: 1.6, cap: 5)
        let score = negative - positive
        let base: FoodGrade
        switch score {
        case ...(-1): base = .a
        case 0...2: base = .b
        case 3...10: base = .c
        case 11...18: base = .d
        default: base = .e
        }
        // Lean-protein bonus: protein-dense, low-sugar whole foods (chicken thigh, salmon, eggs)
        // move up a step, since total fat overstates saturated fat for them. Only foods already
        // at C or better qualify, so bacon, sausage and other D/E foods aren't lifted.
        if proteinPer100g >= 15, sugarPer100g < 5, base >= .c, let next = FoodGrade(rawValue: base.rawValue + 1) {
            return next
        }
        return base
    }

    /// Calorie-weighted average so a splash of milk doesn't count as much as a full plate.
    /// Falls back to an even average when none of the graded items carry calories.
    /// Returns nil when nothing is graded.
    static func average(of weighted: [(grade: FoodGrade, weight: Double)]) -> FoodGrade? {
        guard !weighted.isEmpty else { return nil }
        let totalWeight = weighted.reduce(0) { $0 + max($1.weight, 0) }
        if totalWeight > 0 {
            let sum = weighted.reduce(0) { $0 + Double($1.grade.rawValue) * max($1.weight, 0) }
            return FoodGrade(averagePoints: sum / totalWeight)
        }
        let sum = weighted.reduce(0) { $0 + Double($1.grade.rawValue) }
        return FoodGrade(averagePoints: sum / Double(weighted.count))
    }
}

extension FoodItem {
    /// Official Nutri-Score when Open Food Facts supplied one, otherwise an estimate from
    /// the stored nutrients. Nil when there's no nutrient data to grade.
    var grade: FoodGrade? {
        if let official = FoodGrade(nutriScore: nutriScoreRaw) { return official }
        guard servingSizeGrams >= 5 else { return nil }
        guard calories + sugarGrams + fatGrams + sodiumMilligrams + fiberGrams + proteinGrams > 0 else { return nil }
        let scale = 100 / servingSizeGrams
        return .estimate(caloriesPer100g: calories * scale, sugarPer100g: sugarGrams * scale,
                         fatPer100g: fatGrams * scale, sodiumMgPer100g: sodiumMilligrams * scale,
                         fiberPer100g: fiberGrams * scale, proteinPer100g: proteinGrams * scale)
    }

    var isGradeEstimated: Bool { FoodGrade(nutriScore: nutriScoreRaw) == nil }
}

extension FoodResult {
    /// Official Nutri-Score when present, otherwise an estimate from the serving's nutrients.
    var grade: FoodGrade? {
        if let official = FoodGrade(nutriScore: nutriScore) { return official }
        guard servingSizeGrams >= 5 else { return nil }
        guard calories + sugarGrams + fatGrams + sodiumMilligrams + fiberGrams + proteinGrams > 0 else { return nil }
        let scale = 100 / servingSizeGrams
        return .estimate(caloriesPer100g: calories * scale, sugarPer100g: sugarGrams * scale,
                         fatPer100g: fatGrams * scale, sodiumMgPer100g: sodiumMilligrams * scale,
                         fiberPer100g: fiberGrams * scale, proteinPer100g: proteinGrams * scale)
    }

    var isGradeEstimated: Bool { FoodGrade(nutriScore: nutriScore) == nil }
}

extension Collection where Element == NutritionEntry {
    /// Meal or day grade: the calorie-weighted average of its foods' grades.
    var averageGrade: FoodGrade? {
        FoodGrade.average(of: compactMap { entry in
            guard let grade = entry.foodItem?.grade else { return nil }
            return (grade, entry.calories)
        })
    }
}

struct GradeBadge: View {
    let grade: FoodGrade
    var size: CGFloat = 24

    var body: some View {
        Text(grade.letter)
            .font(.system(size: size * 0.58, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(grade.color))
            .accessibilityLabel("Grade \(grade.letter)")
    }
}
