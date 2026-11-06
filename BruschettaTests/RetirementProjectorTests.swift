import Testing
import Foundation
@testable import Bruschetta

/// Expected values are computed independently of the engine, either by hand or from the
/// standard compound-interest formulas noted on each test.
struct RetirementProjectorTests {
    private let flat = ProjectionAssumptions(stockRealReturn: 0, bondRealReturn: 0, withdrawalRate: 0.04)

    private func account(balance: Double = 0, monthly: Double = 0, stock: Double = 1, months: Int) -> ProjectionAccount {
        ProjectionAccount(balance: balance, monthlyContribution: monthly, stockFraction: stock, contributionMonths: months)
    }

    // MARK: - Growth

    @Test
    func zeroReturnAddsUpContributions() {
        // $1,000 a month for 10 years with no growth is exactly $120,000.
        let value = RetirementProjector.futureValue(of: account(monthly: 1_000, months: 120), assumptions: flat, totalMonths: 120)
        #expect(abs(value - 120_000) < 0.001)
    }

    @Test
    func lumpSumCompoundsAtTheAnnualRate() {
        // Compound interest: FV = PV * (1 + r)^n. $10,000 at 7% for 10 years = $19,671.51.
        let assumptions = ProjectionAssumptions(stockRealReturn: 0.07, bondRealReturn: 0, withdrawalRate: 0.04)
        let value = RetirementProjector.futureValue(of: account(balance: 10_000, months: 0), assumptions: assumptions, totalMonths: 120)
        #expect(abs(value - 10_000 * pow(1.07, 10)) < 0.01)
        #expect(abs(value - 19_671.51) < 0.01)
    }

    @Test
    func contributionsMatchTheFutureValueOfAnAnnuityFormula() {
        // Future value of an ordinary annuity: FV = P * ((1 + i)^n - 1) / i, with i the monthly
        // rate equivalent to a 6% annual return.
        let assumptions = ProjectionAssumptions(stockRealReturn: 0.06, bondRealReturn: 0, withdrawalRate: 0.04)
        let i = pow(1.06, 1.0 / 12) - 1
        let expected = 1_000 * (pow(1 + i, 120) - 1) / i
        let value = RetirementProjector.futureValue(of: account(monthly: 1_000, months: 120), assumptions: assumptions, totalMonths: 120)
        #expect(abs(value - expected) < 0.01)
    }

    @Test
    func contributionsStopWhenTheOwnerRetires() {
        // 12 months of $100, then 12 more months with no contributions and no growth.
        let value = RetirementProjector.futureValue(of: account(monthly: 100, months: 12), assumptions: flat, totalMonths: 24)
        #expect(abs(value - 1_200) < 0.001)
    }

    @Test
    func noTimeLeftReturnsTheCurrentBalance() {
        let value = RetirementProjector.futureValue(of: account(balance: 5_000, monthly: 500, months: 0), assumptions: .defaults, totalMonths: 0)
        #expect(value == 5_000)
    }

    @Test
    func blendedReturnWeightsStocksAndBonds() {
        // 60% * 5% + 40% * 1.5% = 3.6%.
        let blended = RetirementProjector.blendedReturn(stockFraction: 0.6, assumptions: .defaults)
        #expect(abs(blended - 0.036) < 1e-9)
    }

    @Test
    func blendedReturnClampsOutOfRangeAllocations() {
        let high = RetirementProjector.blendedReturn(stockFraction: 3, assumptions: .defaults)
        let low = RetirementProjector.blendedReturn(stockFraction: -1, assumptions: .defaults)
        #expect(abs(high - 0.05) < 1e-9)
        #expect(abs(low - 0.015) < 1e-9)
    }

    // MARK: - Series and scenarios

    @Test
    func seriesIsSampledYearlyAndEndsAtTheFinalValue() {
        let accounts = [account(balance: 1_000, monthly: 100, months: 30)]
        let series = RetirementProjector.series(for: accounts, assumptions: .defaults, totalMonths: 30)
        #expect(series.map(\.month) == [0, 12, 24, 30])
        #expect(series.first?.balance == 1_000)
        let final = RetirementProjector.futureValue(of: accounts[0], assumptions: .defaults, totalMonths: 30)
        #expect(abs((series.last?.balance ?? 0) - final) < 1e-9)
    }

    @Test
    func seriesSumsAccounts() {
        let a = account(balance: 100, months: 0)
        let b = account(balance: 250, months: 0)
        let series = RetirementProjector.series(for: [a, b], assumptions: flat, totalMonths: 24)
        #expect(series.allSatisfy { abs($0.balance - 350) < 1e-9 })
    }

    @Test
    func lowAndHighScenariosBracketTheExpectedCase() {
        let outlook = RetirementProjector.outlook(
            accounts: [account(balance: 50_000, monthly: 800, stock: 0.6, months: 240)],
            assumptions: .defaults, totalMonths: 240, targetAnnualIncome: 80_000
        )
        #expect(outlook.low < outlook.expected)
        #expect(outlook.expected < outlook.high)
    }

    // MARK: - Goal math

    @Test
    func requiredNestEggIsIncomeOverWithdrawalRate() {
        // $80,000 a year at a 4% withdrawal rate needs $2,000,000.
        #expect(RetirementProjector.requiredNestEgg(targetAnnualIncome: 80_000, withdrawalRate: 0.04) == 2_000_000)
        #expect(RetirementProjector.requiredNestEgg(targetAnnualIncome: 80_000, withdrawalRate: 0) == 0)
    }

    @Test
    func contributionNeededActuallyClosesTheGap() {
        let shortfall = 250_000.0
        let monthly = RetirementProjector.monthlyContributionNeeded(shortfall: shortfall, annualReturn: 0.04, months: 180)
        #expect(monthly != nil)
        let assumptions = ProjectionAssumptions(stockRealReturn: 0.04, bondRealReturn: 0.04, withdrawalRate: 0.04)
        let grown = RetirementProjector.futureValue(of: account(monthly: monthly ?? 0, months: 180), assumptions: assumptions, totalMonths: 180)
        #expect(abs(grown - shortfall) < 0.01)
    }

    @Test
    func contributionNeededWithNoGrowthIsEvenSplit() {
        let monthly = RetirementProjector.monthlyContributionNeeded(shortfall: 12_000, annualReturn: 0, months: 120)
        #expect(monthly == 100)
    }

    @Test
    func noContributionNeededWithoutAGapOrTime() {
        #expect(RetirementProjector.monthlyContributionNeeded(shortfall: 0, annualReturn: 0.04, months: 100) == nil)
        #expect(RetirementProjector.monthlyContributionNeeded(shortfall: 1_000, annualReturn: 0.04, months: 0) == nil)
    }

    @Test
    func statusThresholds() {
        #expect(RetirementProjector.status(forProgress: 1.0) == .onTrack)
        #expect(RetirementProjector.status(forProgress: 1.4) == .onTrack)
        #expect(RetirementProjector.status(forProgress: 0.8) == .close)
        #expect(RetirementProjector.status(forProgress: 0.79) == .behind)
    }

    @Test
    func outlookReportsGapAndStatus() {
        // $400k growing at 0% with no contributions against a $2M goal is 20% of the way there.
        let outlook = RetirementProjector.outlook(
            accounts: [account(balance: 400_000, months: 0)],
            assumptions: flat, totalMonths: 120, targetAnnualIncome: 80_000
        )
        #expect(outlook.requiredNestEgg == 2_000_000)
        #expect(abs((outlook.progress ?? 0) - 0.2) < 1e-9)
        #expect(outlook.status == .behind)
        #expect(outlook.gap == 1_600_000)
        // Gap spread evenly over 120 months at 0% growth.
        #expect(abs((outlook.extraMonthlyNeeded ?? 0) - 1_600_000.0 / 120) < 0.001)
    }

    @Test
    func noGapMeansNoExtraSavingNeeded() {
        let outlook = RetirementProjector.outlook(
            accounts: [account(balance: 3_000_000, months: 0)],
            assumptions: flat, totalMonths: 120, targetAnnualIncome: 80_000
        )
        #expect(outlook.status == .onTrack)
        #expect(outlook.extraMonthlyNeeded == nil)
    }

    // MARK: - Contribution limits (IRS Notice 2025-67, 2026 limits)

    @Test
    func catchUpLimitsFollowAge() {
        let limits = ContributionLimits.year2026
        #expect(limits.deferralLimit(age: 49) == 24_500)
        #expect(limits.deferralLimit(age: 50) == 32_500)
        #expect(limits.deferralLimit(age: 59) == 32_500)
        #expect(limits.deferralLimit(age: 60) == 35_750)
        #expect(limits.deferralLimit(age: 63) == 35_750)
        #expect(limits.deferralLimit(age: 64) == 32_500)
        #expect(limits.iraLimit(age: 49) == 7_500)
        #expect(limits.iraLimit(age: 50) == 8_600)
    }

    @Test
    func warnsWhenWorkplaceContributionsExceedTheLimit() {
        // $2,100 a month is $25,200 a year, over the $24,500 limit for someone under 50.
        let entries = [
            ContributionLimitChecker.Entry(type: .k401, ownerOrder: 0, monthlyEmployeeContribution: 2_100)
        ]
        let warnings = ContributionLimitChecker.warnings(entries: entries, ageAtEndOfYearByOwner: [0: 40])
        #expect(warnings.count == 1)
        #expect(warnings.first?.group == .workplacePlan)
        #expect(warnings.first?.limit == 24_500)
        // The same contribution is fine once the age-50 catch-up applies.
        #expect(ContributionLimitChecker.warnings(entries: entries, ageAtEndOfYearByOwner: [0: 52]).isEmpty)
    }

    @Test
    func limitIsSharedAcrossAccountsInAGroupButNotAcrossOwners() {
        // 401(k) plus Roth 401(k) share one limit for the same person: 2 * $1,200 * 12 = $28,800.
        let shared = [
            ContributionLimitChecker.Entry(type: .k401, ownerOrder: 0, monthlyEmployeeContribution: 1_200),
            ContributionLimitChecker.Entry(type: .roth401k, ownerOrder: 0, monthlyEmployeeContribution: 1_200)
        ]
        #expect(ContributionLimitChecker.warnings(entries: shared, ageAtEndOfYearByOwner: [0: 40]).count == 1)

        // The same amounts split between two people are each under their own limit.
        let split = [
            ContributionLimitChecker.Entry(type: .k401, ownerOrder: 0, monthlyEmployeeContribution: 1_200),
            ContributionLimitChecker.Entry(type: .k401, ownerOrder: 1, monthlyEmployeeContribution: 1_200)
        ]
        #expect(ContributionLimitChecker.warnings(entries: split, ageAtEndOfYearByOwner: [0: 40, 1: 40]).isEmpty)
    }

    @Test
    func iraAndBrokerageAreCheckedSeparately() {
        let entries = [
            ContributionLimitChecker.Entry(type: .rothIRA, ownerOrder: 0, monthlyEmployeeContribution: 700),
            ContributionLimitChecker.Entry(type: .brokerage, ownerOrder: 0, monthlyEmployeeContribution: 50_000)
        ]
        let warnings = ContributionLimitChecker.warnings(entries: entries, ageAtEndOfYearByOwner: [0: 40])
        // $700 * 12 = $8,400 is over the $7,500 IRA limit; brokerage has no limit.
        #expect(warnings.count == 1)
        #expect(warnings.first?.group == .ira)
    }
}
