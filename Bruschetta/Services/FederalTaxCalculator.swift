import Foundation

enum FilingStatus: Equatable {
    case single
    case marriedJoint
}

/// Federal tax figures for one tax year. Update each year from the IRS revenue procedure
/// listed in RetirementSources.federalTax.
struct TaxYearData: Equatable {
    struct Bracket: Equatable {
        /// Top of the bracket in taxable income; infinity for the last one.
        let upTo: Double
        let rate: Double
    }

    let taxYear: Int
    let singleBrackets: [Bracket]
    let jointBrackets: [Bracket]
    let standardDeductionSingle: Double
    let standardDeductionJoint: Double
    /// Extra standard deduction per person aged 65 or older.
    let agedAddOnMarried: Double
    let agedAddOnUnmarried: Double
    /// Taxable-income ceilings for the 0% and 15% long-term capital gains rates.
    let zeroRateCeilingSingle: Double
    let fifteenRateCeilingSingle: Double
    let zeroRateCeilingJoint: Double
    let fifteenRateCeilingJoint: Double

    /// IRS Rev. Proc. 2025-32 (tax year 2026).
    static let year2026 = TaxYearData(
        taxYear: 2026,
        singleBrackets: [
            .init(upTo: 12_400, rate: 0.10), .init(upTo: 50_400, rate: 0.12), .init(upTo: 105_700, rate: 0.22),
            .init(upTo: 201_775, rate: 0.24), .init(upTo: 256_225, rate: 0.32), .init(upTo: 640_600, rate: 0.35),
            .init(upTo: .infinity, rate: 0.37)
        ],
        jointBrackets: [
            .init(upTo: 24_800, rate: 0.10), .init(upTo: 100_800, rate: 0.12), .init(upTo: 211_400, rate: 0.22),
            .init(upTo: 403_550, rate: 0.24), .init(upTo: 512_450, rate: 0.32), .init(upTo: 768_700, rate: 0.35),
            .init(upTo: .infinity, rate: 0.37)
        ],
        standardDeductionSingle: 16_100,
        standardDeductionJoint: 32_200,
        agedAddOnMarried: 1_650,
        agedAddOnUnmarried: 2_050,
        zeroRateCeilingSingle: 49_450,
        fifteenRateCeilingSingle: 545_500,
        zeroRateCeilingJoint: 98_900,
        fifteenRateCeilingJoint: 613_700
    )

    static let current = year2026
}

struct TaxBreakdown: Equatable {
    let taxableSocialSecurity: Double
    let adjustedGrossIncome: Double
    let deduction: Double
    let taxableIncome: Double
    let federalTax: Double
}

/// Federal income tax for a retirement-income year: ordinary income (pre-tax withdrawals),
/// long-term capital gains (from taxable accounts) and Social Security. In today's dollars,
/// using the current-year tables for every year.
enum FederalTaxCalculator {
    /// Portion of Social Security benefits that is taxable, per IRS Publication 915, Worksheet 1.
    /// `otherIncome` is all income other than Social Security.
    static func taxableSocialSecurity(benefits: Double, otherIncome: Double, status: FilingStatus) -> Double {
        guard benefits > 0 else { return 0 }
        let base = status == .marriedJoint ? 32_000.0 : 25_000.0
        let gap = status == .marriedJoint ? 12_000.0 : 9_000.0

        let combined = otherIncome + 0.5 * benefits
        let overBase = combined - base
        guard overBase > 0 else { return 0 }

        let overUpper = max(0, overBase - gap)
        let fiftyPercentTier = min(0.5 * benefits, 0.5 * min(overBase, gap))
        let eightyFivePercentTier = 0.85 * overUpper
        return min(fiftyPercentTier + eightyFivePercentTier, 0.85 * benefits)
    }

    static func bracketTax(taxableIncome: Double, brackets: [TaxYearData.Bracket]) -> Double {
        var tax = 0.0
        var lower = 0.0
        for bracket in brackets {
            guard taxableIncome > lower else { break }
            tax += (min(taxableIncome, bracket.upTo) - lower) * bracket.rate
            lower = bracket.upTo
        }
        return tax
    }

    /// `agedCount` is how many filers are 65 or older (each gets the extra standard deduction).
    static func compute(
        socialSecurity: Double,
        ordinaryIncome: Double,
        longTermGains: Double,
        status: FilingStatus,
        agedCount: Int,
        data: TaxYearData = .current
    ) -> TaxBreakdown {
        let taxableSS = taxableSocialSecurity(benefits: socialSecurity, otherIncome: ordinaryIncome + longTermGains, status: status)
        let agi = ordinaryIncome + longTermGains + taxableSS

        let baseDeduction = status == .marriedJoint ? data.standardDeductionJoint : data.standardDeductionSingle
        let addOn = status == .marriedJoint ? data.agedAddOnMarried : data.agedAddOnUnmarried
        let deduction = baseDeduction + Double(agedCount) * addOn

        let taxableIncome = max(0, agi - deduction)
        let gainsInIncome = min(max(0, longTermGains), taxableIncome)
        let ordinaryTaxable = taxableIncome - gainsInIncome

        let brackets = status == .marriedJoint ? data.jointBrackets : data.singleBrackets
        let ordinaryTax = bracketTax(taxableIncome: ordinaryTaxable, brackets: brackets)

        // Gains are stacked on top of ordinary income when finding which rate applies.
        let zeroCeiling = status == .marriedJoint ? data.zeroRateCeilingJoint : data.zeroRateCeilingSingle
        let fifteenCeiling = status == .marriedJoint ? data.fifteenRateCeilingJoint : data.fifteenRateCeilingSingle
        let bottom = ordinaryTaxable
        let top = taxableIncome
        let at15 = max(0, min(top, fifteenCeiling) - max(bottom, zeroCeiling))
        let at20 = max(0, top - max(bottom, fifteenCeiling))
        let gainsTax = at15 * 0.15 + at20 * 0.20

        return TaxBreakdown(
            taxableSocialSecurity: taxableSS,
            adjustedGrossIncome: agi,
            deduction: deduction,
            taxableIncome: taxableIncome,
            federalTax: ordinaryTax + gainsTax
        )
    }
}

/// Required minimum distributions from pre-tax accounts.
enum RequiredDistributions {
    /// Age RMDs begin: 73 for anyone born 1959 or earlier, 75 for 1960 and later (SECURE 2.0).
    /// The law is ambiguous for 1959 births; 73 is the earlier, more conservative age.
    static func startAge(birthYear: Int) -> Int {
        birthYear >= 1960 ? 75 : 73
    }

    /// IRS Uniform Lifetime Table (Publication 590-B, Table III), ages 72 and up.
    private static let uniformLifetime: [Int: Double] = [
        72: 27.4, 73: 26.5, 74: 25.5, 75: 24.6, 76: 23.7, 77: 22.9, 78: 22.0, 79: 21.1, 80: 20.2,
        81: 19.4, 82: 18.5, 83: 17.7, 84: 16.8, 85: 16.0, 86: 15.2, 87: 14.4, 88: 13.7, 89: 12.9,
        90: 12.2, 91: 11.5, 92: 10.8, 93: 10.1, 94: 9.5, 95: 8.9, 96: 8.4, 97: 7.8, 98: 7.3,
        99: 6.8, 100: 6.4, 101: 6.0, 102: 5.6, 103: 5.2, 104: 4.9, 105: 4.6, 106: 4.3, 107: 4.1,
        108: 3.9, 109: 3.7, 110: 3.5, 111: 3.4, 112: 3.3, 113: 3.1, 114: 3.0, 115: 2.9, 116: 2.8,
        117: 2.7, 118: 2.5, 119: 2.3
    ]

    /// Distribution period for an age; 2.0 for 120 and over.
    static func distributionPeriod(age: Int) -> Double {
        if age >= 120 { return 2.0 }
        return uniformLifetime[max(age, 72)] ?? 27.4
    }

    static func requiredDistribution(balance: Double, age: Int) -> Double {
        guard balance > 0 else { return 0 }
        return balance / distributionPeriod(age: age)
    }
}
