import Foundation

/// Social Security retirement benefit math. Sources are listed in RetirementSources.socialSecurity.
enum SocialSecurityCalculator {
    struct Parameters: Equatable {
        let year: Int
        /// Monthly AIME bend points for the primary insurance amount formula.
        let bendPoint1: Double
        let bendPoint2: Double
        /// Maximum annual earnings subject to Social Security tax.
        let wageBase: Double

        /// SSA bend points for workers first eligible in 2026, and the 2026 contribution and
        /// benefit base.
        static let year2026 = Parameters(year: 2026, bendPoint1: 1_286, bendPoint2: 7_749, wageBase: 184_500)
        static let current = year2026
    }

    /// Full retirement age in months for a birth year: 66 for 1954 and earlier, rising two
    /// months a year to 66 and 10 months for 1959, and 67 for 1960 and later.
    static func fraMonths(birthYear: Int) -> Int {
        switch birthYear {
        case ...1954: return 66 * 12
        case 1955...1959: return 66 * 12 + (birthYear - 1954) * 2
        default: return 67 * 12
        }
    }

    /// Multiplier on the full-retirement-age benefit for claiming at `claimAgeMonths`.
    /// Claiming early cuts 5/9 of 1% per month for the first 36 months and 5/12 of 1% for each
    /// month after that. Waiting past full retirement age adds 2/3 of 1% per month (8% a year),
    /// with no credit after age 70.
    static func claimingFactor(claimAgeMonths: Int, fraMonths: Int) -> Double {
        if claimAgeMonths < fraMonths {
            let early = fraMonths - claimAgeMonths
            let firstTier = min(early, 36)
            let secondTier = max(0, early - 36)
            return 1 - (Double(firstTier) * 5.0 / 900.0 + Double(secondTier) * 5.0 / 1200.0)
        }
        let late = max(0, min(claimAgeMonths, 70 * 12) - fraMonths)
        return 1 + Double(late) * (2.0 / 3.0) / 100.0
    }

    /// Monthly benefit when claiming at a whole-year age, given the full-retirement-age amount.
    static func monthlyBenefit(piaAtFRA: Double, claimAge: Int, birthYear: Int) -> Double {
        let clamped = min(max(claimAge, 62), 70)
        return piaAtFRA * claimingFactor(claimAgeMonths: clamped * 12, fraMonths: fraMonths(birthYear: birthYear))
    }

    /// Primary insurance amount from average indexed monthly earnings: 90% of the first bend
    /// point, 32% up to the second, and 15% above it.
    static func primaryInsuranceAmount(aime: Double, parameters: Parameters = .current) -> Double {
        let amount = max(0, aime)
        let tier1 = min(amount, parameters.bendPoint1)
        let tier2 = max(0, min(amount, parameters.bendPoint2) - parameters.bendPoint1)
        let tier3 = max(0, amount - parameters.bendPoint2)
        return 0.9 * tier1 + 0.32 * tier2 + 0.15 * tier3
    }

    /// A rough monthly benefit at full retirement age, assuming a full 35-year career at the
    /// current gross income (capped at the wage base). Real earnings histories vary, so the
    /// figure from the person's ssa.gov statement should be used instead whenever it's known.
    static func estimatedPIA(annualGross: Double, parameters: Parameters = .current) -> Double {
        let aime = min(max(annualGross, 0), parameters.wageBase) / 12
        return primaryInsuranceAmount(aime: aime, parameters: parameters)
    }
}
