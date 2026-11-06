import Foundation

/// Annual IRS contribution limits for one tax year. Update this file each year from the IRS
/// announcement listed in RetirementSources.contributionLimits.
struct ContributionLimits: Equatable {
    let taxYear: Int
    /// Employee deferral limit for 401(k), 403(b) and similar workplace plans.
    let employeeDeferral: Double
    /// Extra deferral allowed from age 50.
    let catchUp50: Double
    /// Extra deferral allowed at ages 60 through 63, in place of the age-50 catch-up.
    let catchUp60to63: Double
    let iraLimit: Double
    /// Extra IRA contribution allowed from age 50.
    let iraCatchUp50: Double

    /// IRS Notice 2025-67 / IR-2025-111 (announced November 2025).
    static let year2026 = ContributionLimits(
        taxYear: 2026,
        employeeDeferral: 24_500,
        catchUp50: 8_000,
        catchUp60to63: 11_250,
        iraLimit: 7_500,
        iraCatchUp50: 1_100
    )

    static let current = year2026

    /// `age` is the age reached by the end of the tax year.
    func deferralLimit(age: Int) -> Double {
        if (60...63).contains(age) { return employeeDeferral + catchUp60to63 }
        if age >= 50 { return employeeDeferral + catchUp50 }
        return employeeDeferral
    }

    func iraLimit(age: Int) -> Double {
        age >= 50 ? iraLimit + iraCatchUp50 : iraLimit
    }
}

enum ContributionGroup: Equatable {
    case workplacePlan
    case ira

    var title: String {
        switch self {
        case .workplacePlan: return "401(k) / 403(b)"
        case .ira: return "IRA"
        }
    }
}

struct ContributionWarning: Equatable, Identifiable {
    let ownerOrder: Int
    let group: ContributionGroup
    let annualAmount: Double
    let limit: Double
    var id: String { "\(ownerOrder)-\(group.title)" }
}

enum ContributionLimitChecker {
    struct Entry {
        let type: RetirementAccountType
        let ownerOrder: Int
        let monthlyEmployeeContribution: Double
    }

    /// Flags owners whose combined employee contributions in a group exceed the annual limit.
    /// Workplace-plan limits are shared across 401(k), Roth 401(k) and 403(b); IRA limits are
    /// shared across Traditional and Roth IRAs. SEP and brokerage accounts are not checked.
    /// Employer contributions don't count toward these employee limits.
    static func warnings(entries: [Entry], ageAtEndOfYearByOwner: [Int: Int], limits: ContributionLimits = .current) -> [ContributionWarning] {
        var totals: [Int: [ContributionGroup: Double]] = [:]
        for entry in entries {
            let group: ContributionGroup
            switch entry.type {
            case .k401, .roth401k, .k403b: group = .workplacePlan
            case .traditionalIRA, .rothIRA: group = .ira
            case .sepIRA, .brokerage, .other: continue
            }
            totals[entry.ownerOrder, default: [:]][group, default: 0] += entry.monthlyEmployeeContribution * 12
        }

        var result: [ContributionWarning] = []
        for owner in totals.keys.sorted() {
            guard let age = ageAtEndOfYearByOwner[owner] else { continue }
            for group in [ContributionGroup.workplacePlan, .ira] {
                guard let amount = totals[owner]?[group] else { continue }
                let limit = group == .workplacePlan ? limits.deferralLimit(age: age) : limits.iraLimit(age: age)
                if amount > limit + 0.005 {
                    result.append(ContributionWarning(ownerOrder: owner, group: group, annualAmount: amount, limit: limit))
                }
            }
        }
        return result
    }
}
