import Foundation
import SwiftData

/// How the user's retirement income target is expressed.
enum RetirementTargetMode: String, CaseIterable, Identifiable {
    case percentOfGross
    case fixedDollars

    var id: String { rawValue }
}

/// The household's retirement plan. There is at most one. All properties have defaults so the
/// model stays CloudKit-compatible, and nothing here is created until the user opts into
/// retirement tracking and runs setup.
@Model
final class RetirementPlan {
    /// Two people (married filing jointly) when true, otherwise a single filer.
    var isCouple: Bool = false
    var targetModeRaw: String = RetirementTargetMode.percentOfGross.rawValue
    /// Percent of combined gross income wanted in retirement. 80 is the app default.
    var targetPercent: Double = RetirementPlan.defaultTargetPercent
    /// Desired retirement income per year (today's dollars), used when mode is `.fixedDollars`.
    var targetDollars: Double = 0
    var isSetupComplete: Bool = false

    static let defaultTargetPercent: Double = 80

    init(isCouple: Bool = false) {
        self.isCouple = isCouple
    }

    var targetMode: RetirementTargetMode {
        get { RetirementTargetMode(rawValue: targetModeRaw) ?? .percentOfGross }
        set { targetModeRaw = newValue.rawValue }
    }

    /// True while the user is on the untouched 80%-of-gross default.
    var isUsingDefaultTarget: Bool {
        targetMode == .percentOfGross && targetPercent == RetirementPlan.defaultTargetPercent
    }

    /// Target retirement income per year in today's dollars, given the household's combined
    /// gross income.
    func targetAnnualIncome(combinedGross: Double) -> Double {
        switch targetMode {
        case .percentOfGross: return combinedGross * targetPercent / 100
        case .fixedDollars: return targetDollars
        }
    }
}

/// A person covered by the plan: one for a single filer, two for a couple. Sorted by `order`.
@Model
final class PlanPerson {
    var order: Int = 0
    var name: String = ""
    var birthDate: Date = Date()
    /// Annual income before taxes and deductions.
    var grossAnnualIncome: Double = 0
    var retirementAge: Int = 67

    init(order: Int, name: String = "", birthDate: Date? = nil, grossAnnualIncome: Double = 0, retirementAge: Int = 67) {
        self.order = order
        self.name = name
        self.birthDate = birthDate
            ?? Calendar.current.date(byAdding: .year, value: -35, to: Date())
            ?? Date()
        self.grossAnnualIncome = grossAnnualIncome
        self.retirementAge = retirementAge
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var yearsToRetirement: Int {
        max(0, retirementAge - age)
    }

    func displayName(fallbackIndex: Int) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return fallbackIndex == 0 ? "You" : "Partner"
    }
}
