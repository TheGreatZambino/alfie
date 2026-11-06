import Testing
import Foundation
@testable import Bruschetta

/// Expected values are worked out by hand from the cited tables and worksheets, not copied from
/// the code under test. Sources: IRS Rev. Proc. 2025-32 (2026 brackets, deductions and capital
/// gains ceilings), IRS Publication 915 Worksheet 1, IRS Publication 590-B Table III, and the
/// SSA benefit formula and claiming rules.
struct SocialSecurityCalculatorTests {
    @Test
    func fullRetirementAgeByBirthYear() {
        #expect(SocialSecurityCalculator.fraMonths(birthYear: 1954) == 66 * 12)
        #expect(SocialSecurityCalculator.fraMonths(birthYear: 1957) == 66 * 12 + 6)
        #expect(SocialSecurityCalculator.fraMonths(birthYear: 1959) == 66 * 12 + 10)
        #expect(SocialSecurityCalculator.fraMonths(birthYear: 1960) == 67 * 12)
        #expect(SocialSecurityCalculator.fraMonths(birthYear: 1990) == 67 * 12)
    }

    @Test
    func claimingAt62WithFRA67CutsBenefitBy30Percent() {
        // 36 months * 5/9% + 24 months * 5/12% = 20% + 10% = 30% (SSA).
        let factor = SocialSecurityCalculator.claimingFactor(claimAgeMonths: 62 * 12, fraMonths: 67 * 12)
        #expect(abs(factor - 0.70) < 1e-9)
    }

    @Test
    func claimingAt62WithFRA66CutsBenefitBy25Percent() {
        // 36 months * 5/9% + 12 months * 5/12% = 20% + 5% = 25% (SSA).
        let factor = SocialSecurityCalculator.claimingFactor(claimAgeMonths: 62 * 12, fraMonths: 66 * 12)
        #expect(abs(factor - 0.75) < 1e-9)
    }

    @Test
    func claimingAtFullRetirementAgeIsUnchanged() {
        #expect(SocialSecurityCalculator.claimingFactor(claimAgeMonths: 67 * 12, fraMonths: 67 * 12) == 1)
    }

    @Test
    func delayingToSeventyAddsEightPercentPerYear() {
        // 3 years past FRA 67 at 8% a year = 24%.
        let factor = SocialSecurityCalculator.claimingFactor(claimAgeMonths: 70 * 12, fraMonths: 67 * 12)
        #expect(abs(factor - 1.24) < 1e-9)
        // Credits stop at 70.
        #expect(SocialSecurityCalculator.monthlyBenefit(piaAtFRA: 1_000, claimAge: 75, birthYear: 1990) == 1_240)
    }

    @Test
    func monthlyBenefitAppliesTheClaimingFactor() {
        #expect(abs(SocialSecurityCalculator.monthlyBenefit(piaAtFRA: 2_000, claimAge: 62, birthYear: 1990) - 1_400) < 1e-6)
    }

    @Test
    func primaryInsuranceAmountFollowsTheThreeTierFormula() {
        let p = SocialSecurityCalculator.Parameters.year2026   // bend points 1,286 and 7,749
        // AIME 1,000: 90% of 1,000 = 900.
        #expect(abs(SocialSecurityCalculator.primaryInsuranceAmount(aime: 1_000, parameters: p) - 900) < 1e-9)
        // AIME 5,000: 0.9*1,286 + 0.32*(5,000 - 1,286) = 1,157.40 + 1,188.48 = 2,345.88.
        #expect(abs(SocialSecurityCalculator.primaryInsuranceAmount(aime: 5_000, parameters: p) - 2_345.88) < 1e-6)
        // AIME 10,000: 1,157.40 + 0.32*(7,749 - 1,286) + 0.15*(10,000 - 7,749) = 1,157.40 + 2,068.16 + 337.65.
        #expect(abs(SocialSecurityCalculator.primaryInsuranceAmount(aime: 10_000, parameters: p) - 3_563.21) < 1e-6)
    }

    @Test
    func estimateCapsEarningsAtTheWageBase() {
        let atCap = SocialSecurityCalculator.estimatedPIA(annualGross: 184_500)
        let above = SocialSecurityCalculator.estimatedPIA(annualGross: 500_000)
        #expect(abs(atCap - above) < 1e-9)
        // $60,000 a year is an AIME of 5,000.
        #expect(abs(SocialSecurityCalculator.estimatedPIA(annualGross: 60_000) - 2_345.88) < 1e-6)
    }
}

struct FederalTaxCalculatorTests {
    @Test
    func singleBracketTax() {
        // 10% of 12,400 = 1,240; 12% of (50,000 - 12,400) = 4,512; total 5,752.
        let tax = FederalTaxCalculator.bracketTax(taxableIncome: 50_000, brackets: TaxYearData.year2026.singleBrackets)
        #expect(abs(tax - 5_752) < 1e-6)
    }

    @Test
    func jointBracketTax() {
        // 10% of 24,800 = 2,480; 12% of (100,000 - 24,800) = 9,024; total 11,504.
        let tax = FederalTaxCalculator.bracketTax(taxableIncome: 100_000, brackets: TaxYearData.year2026.jointBrackets)
        #expect(abs(tax - 11_504) < 1e-6)
    }

    @Test
    func bracketsMatchTheIRSPublishedBaseAmounts() {
        // Rev. Proc. 2025-32 lists "$5,800 plus 22% of the excess over $50,400" (single) and
        // "$206,583.50 plus 37% of the excess over $768,700" (joint).
        let single = FederalTaxCalculator.bracketTax(taxableIncome: 50_400, brackets: TaxYearData.year2026.singleBrackets)
        #expect(abs(single - 5_800) < 1e-6)
        let joint = FederalTaxCalculator.bracketTax(taxableIncome: 768_700, brackets: TaxYearData.year2026.jointBrackets)
        #expect(abs(joint - 206_583.5) < 1e-6)
    }

    @Test
    func standardDeductionAndAgedAddOn() {
        // Ordinary income of 66,100 less the 16,100 standard deduction is 50,000 taxable.
        let result = FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 66_100, longTermGains: 0, status: .single, agedCount: 0)
        #expect(result.taxableIncome == 50_000)
        #expect(abs(result.federalTax - 5_752) < 1e-6)
        // At 65 or older a single filer gets 2,050 more; joint filers get 1,650 each.
        #expect(FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 0, longTermGains: 0, status: .single, agedCount: 1).deduction == 18_150)
        #expect(FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 0, longTermGains: 0, status: .marriedJoint, agedCount: 2).deduction == 35_500)
    }

    @Test
    func noTaxOnIncomeCoveredByTheDeduction() {
        let result = FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 16_000, longTermGains: 0, status: .single, agedCount: 0)
        #expect(result.federalTax == 0)
    }

    @Test
    func socialSecurityBelowTheBaseAmountIsNotTaxed() {
        // 10,000 other + half of 20,000 benefits = 20,000, under the 25,000 single base.
        #expect(FederalTaxCalculator.taxableSocialSecurity(benefits: 20_000, otherIncome: 10_000, status: .single) == 0)
    }

    @Test
    func socialSecuritySingleWorksheetExample() {
        // Publication 915 Worksheet 1: benefits 30,000, other income 20,000, single.
        // Line 6 = 15,000 + 20,000 = 35,000; line 10 = 10,000; line 12 = 1,000; line 13 = 9,000;
        // line 14 = 4,500; line 15 = 4,500; line 16 = 850; line 17 = 5,350; line 18 = 25,500.
        let taxable = FederalTaxCalculator.taxableSocialSecurity(benefits: 30_000, otherIncome: 20_000, status: .single)
        #expect(abs(taxable - 5_350) < 1e-6)
    }

    @Test
    func socialSecurityJointWorksheetExample() {
        // Benefits 40,000, other income 30,000, joint: line 6 = 50,000; line 10 = 18,000;
        // line 12 = 6,000; line 13 = 12,000; line 14 = 6,000; line 15 = 6,000; line 16 = 5,100;
        // line 17 = 11,100; line 18 = 34,000.
        let taxable = FederalTaxCalculator.taxableSocialSecurity(benefits: 40_000, otherIncome: 30_000, status: .marriedJoint)
        #expect(abs(taxable - 11_100) < 1e-6)
    }

    @Test
    func socialSecurityTaxableAmountIsCappedAt85Percent() {
        let taxable = FederalTaxCalculator.taxableSocialSecurity(benefits: 30_000, otherIncome: 500_000, status: .single)
        #expect(abs(taxable - 25_500) < 1e-6)
    }

    @Test
    func longTermGainsInTheZeroBracketAreNotTaxed() {
        // Taxable income of 40,000, all gains, is under the 49,450 single ceiling.
        let result = FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 0, longTermGains: 56_100, status: .single, agedCount: 0)
        #expect(result.taxableIncome == 40_000)
        #expect(result.federalTax == 0)
    }

    @Test
    func longTermGainsStackOnTopOfOrdinaryIncome() {
        // Ordinary taxable 40,000 (tax 1,240 + 12% * 27,600 = 4,552) plus gains of 20,000.
        // Gains fill 40,000 to 60,000: 9,450 at 0% (up to 49,450) and 10,550 at 15% = 1,582.50.
        let result = FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 56_100, longTermGains: 20_000, status: .single, agedCount: 0)
        #expect(result.taxableIncome == 60_000)
        #expect(abs(result.federalTax - (4_552 + 1_582.5)) < 1e-6)
    }

    @Test
    func gainsAboveTheFifteenPercentCeilingPayTwentyPercent() {
        // Joint, gains only: taxable 700,000 means 613,700 is the 15% ceiling; 86,300 at 20%.
        // 15% portion = 613,700 - 98,900 = 514,800.
        let result = FederalTaxCalculator.compute(socialSecurity: 0, ordinaryIncome: 0, longTermGains: 732_200, status: .marriedJoint, agedCount: 0)
        #expect(result.taxableIncome == 700_000)
        #expect(abs(result.federalTax - (514_800 * 0.15 + 86_300 * 0.20)) < 1e-6)
    }
}

struct RequiredDistributionsTests {
    @Test
    func startAgeDependsOnBirthYear() {
        #expect(RequiredDistributions.startAge(birthYear: 1955) == 73)
        #expect(RequiredDistributions.startAge(birthYear: 1959) == 73)
        #expect(RequiredDistributions.startAge(birthYear: 1960) == 75)
        #expect(RequiredDistributions.startAge(birthYear: 1985) == 75)
    }

    @Test
    func uniformLifetimeTableValues() {
        // IRS Publication 590-B, Table III.
        #expect(RequiredDistributions.distributionPeriod(age: 73) == 26.5)
        #expect(RequiredDistributions.distributionPeriod(age: 75) == 24.6)
        #expect(RequiredDistributions.distributionPeriod(age: 90) == 12.2)
        #expect(RequiredDistributions.distributionPeriod(age: 119) == 2.3)
        #expect(RequiredDistributions.distributionPeriod(age: 125) == 2.0)
    }

    @Test
    func requiredDistributionIsBalanceOverTheFactor() {
        // 265,000 at age 73 is 265,000 / 26.5 = 10,000.
        #expect(abs(RequiredDistributions.requiredDistribution(balance: 265_000, age: 73) - 10_000) < 1e-9)
        #expect(RequiredDistributions.requiredDistribution(balance: 0, age: 80) == 0)
    }
}

struct DrawdownSimulatorTests {
    private let flat = ProjectionAssumptions(stockRealReturn: 0, bondRealReturn: 0)

    private func person(startAge: Int, birthYear: Int = 1960, claimAge: Int = 70, pia: Double = 0) -> DrawdownPerson {
        DrawdownPerson(birthYear: birthYear, ageAtStart: startAge, claimingAge: claimAge, piaAtFRA: pia)
    }

    private func pool(_ balance: Double, basis: Double = 0) -> DrawdownPool {
        DrawdownPool(balance: balance, basis: basis, stockFraction: 0.5)
    }

    private func input(
        people: [DrawdownPerson],
        preTax: [Double]? = nil,
        roth: Double = 0,
        taxable: Double = 0,
        basis: Double = 0,
        spending: Double,
        planToAge: Int = 90,
        state: Double = 0
    ) -> DrawdownInput {
        DrawdownInput(
            people: people,
            preTax: (preTax ?? people.map { _ in 0 }).map { pool($0) },
            roth: pool(roth),
            taxable: pool(taxable, basis: basis),
            annualSpending: spending,
            planToAge: planToAge,
            stateTaxRate: state,
            assumptions: flat
        )
    }

    @Test
    func rothOnlyPlanSpendsDownEvenly() {
        // 25 years (ages 65 to 89) at 40,000, no taxes on Roth, no growth: 1,000,000 is enough.
        let result = DrawdownSimulator.run(input(people: [person(startAge: 65)], roth: 1_000_000, spending: 40_000))
        #expect(result.isFullyFunded)
        #expect(result.years.count == 25)
        #expect(abs((result.years.last?.endingBalance ?? 1) - 0) < 0.01)
        #expect(result.years.allSatisfy { $0.totalTaxes == 0 })
    }

    @Test
    func runsShortInTheFinalYearWhenSavingsAreSlightlyShort() {
        let result = DrawdownSimulator.run(input(people: [person(startAge: 65)], roth: 960_000, spending: 40_000))
        #expect(!result.isFullyFunded)
        #expect(result.firstShortfallAge == 89)
    }

    @Test
    func socialSecurityAloneCanCoverTheGoal() {
        // Claiming at 67 (full retirement age for 1960 births) at 2,500 a month is 30,000 a year.
        // With no other income, half the benefit (15,000) is under the 25,000 base, so none of
        // it is taxed.
        let result = DrawdownSimulator.run(input(
            people: [person(startAge: 67, claimAge: 67, pia: 2_500)], spending: 30_000, planToAge: 70
        ))
        #expect(result.isFullyFunded)
        #expect(abs((result.years.first?.socialSecurity ?? 0) - 30_000) < 1e-6)
        #expect((result.years.first?.federalTax ?? 1) == 0)
    }

    @Test
    func benefitsStartAtTheClaimingAge() {
        let result = DrawdownSimulator.run(input(
            people: [person(startAge: 62, claimAge: 64, pia: 2_000)], roth: 500_000, spending: 20_000, planToAge: 66
        ))
        #expect(result.years.map(\.socialSecurity).prefix(2) == [0, 0])
        #expect((result.years.last?.socialSecurity ?? 0) > 0)
    }

    @Test
    func netIncomeMatchesTheSpendingGoalAfterTaxes() {
        // Pre-tax only: withdrawals are grossed up so income after tax equals the goal.
        let result = DrawdownSimulator.run(input(people: [person(startAge: 62)], preTax: [2_000_000], spending: 60_000, planToAge: 70))
        #expect(result.isFullyFunded)
        for year in result.years {
            #expect(abs(year.netIncome - 60_000) < 0.01)
            #expect(year.preTaxWithdrawal > 60_000)
            #expect(year.federalTax > 0)
        }
    }

    @Test
    func earlyPreTaxWithdrawalsPayThePenalty() {
        // Age 55: a 10% additional tax applies, so gross withdrawal exceeds the no-penalty case.
        let early = DrawdownSimulator.run(input(people: [person(startAge: 55)], preTax: [1_000_000], spending: 40_000, planToAge: 56))
        let later = DrawdownSimulator.run(input(people: [person(startAge: 62)], preTax: [1_000_000], spending: 40_000, planToAge: 63))
        #expect((early.years.first?.penalty ?? 0) > 0)
        #expect((later.years.first?.penalty ?? 1) == 0)
        #expect((early.years.first?.preTaxWithdrawal ?? 0) > (later.years.first?.preTaxWithdrawal ?? 0))
    }

    @Test
    func taxableAccountOnlyTaxesTheGain() {
        // Balance 100,000 with basis 100,000 has no gain, so withdrawing 30,000 costs no tax.
        let noGain = DrawdownSimulator.run(input(people: [person(startAge: 65)], taxable: 100_000, basis: 100_000, spending: 30_000, planToAge: 66))
        #expect((noGain.years.first?.federalTax ?? 1) == 0)
        #expect(abs((noGain.years.first?.taxableWithdrawal ?? 0) - 30_000) < 0.01)
    }

    @Test
    func taxableWithdrawalsAreUsedBeforePreTaxAndRoth() {
        let result = DrawdownSimulator.run(input(
            people: [person(startAge: 65)], preTax: [500_000], roth: 500_000, taxable: 500_000, basis: 500_000,
            spending: 30_000, planToAge: 66
        ))
        let year = result.years[0]
        #expect(year.taxableWithdrawal > 0)
        #expect(year.preTaxWithdrawal == 0)
        #expect(year.rothWithdrawal == 0)
    }

    @Test
    func requiredDistributionsAreTakenEvenWhenNotNeeded() {
        // Born 1960, RMDs start at 75. 2,460,000 / 24.6 = 100,000 forced out at age 75.
        let result = DrawdownSimulator.run(input(
            people: [person(startAge: 75, birthYear: 1960)], preTax: [2_460_000], spending: 20_000, planToAge: 76
        ))
        #expect(abs((result.years.first?.preTaxWithdrawal ?? 0) - 100_000) < 0.01)
        // Income after tax exceeds the goal, and the surplus is reinvested rather than lost.
        #expect(abs((result.years.first?.netIncome ?? 0) - 20_000) > 1)
        #expect((result.years.first?.endingBalance ?? 0) > 2_360_000 - 1)
    }

    @Test
    func stateTaxReducesWhatIsLeft() {
        let none = DrawdownSimulator.run(input(people: [person(startAge: 62)], preTax: [1_000_000], spending: 40_000, planToAge: 63))
        let taxed = DrawdownSimulator.run(input(people: [person(startAge: 62)], preTax: [1_000_000], spending: 40_000, planToAge: 63, state: 0.05))
        #expect((taxed.years.first?.stateTax ?? 0) > 0)
        #expect((taxed.years.first?.preTaxWithdrawal ?? 0) > (none.years.first?.preTaxWithdrawal ?? 0))
    }

    @Test
    func couplePlansUntilTheYoungerReachesThePlanToAge() {
        let result = DrawdownSimulator.run(input(
            people: [person(startAge: 67), person(startAge: 63)], roth: 5_000_000, spending: 50_000, planToAge: 90
        ))
        // The younger person is 63, so the plan runs 27 years.
        #expect(result.years.count == 27)
        #expect(result.years.first?.age == 67)
    }

    @Test
    func savingsNeededSizesTheBalanceToJustFundTheGoal() {
        let base = input(people: [person(startAge: 65)], roth: 100_000, spending: 40_000)
        let needed = RetirementProjector.savingsNeeded(for: base)
        // With no growth and Roth-only money, 25 years of 40,000 needs about 1,000,000.
        #expect(abs((needed ?? 0) - 1_000_000) < 1_000)
        #expect(DrawdownSimulator.run(base.scaled(by: (needed ?? 0) / base.startingBalance * 1.001)).isFullyFunded)
        #expect(!DrawdownSimulator.run(base.scaled(by: (needed ?? 0) / base.startingBalance * 0.99)).isFullyFunded)
    }
}

@MainActor
struct RetirementReportTests {
    private func makeReport(couple: Bool) -> RetirementReport? {
        let plan = RetirementPlan(isCouple: couple)
        plan.isSetupComplete = true
        let birth = Calendar.current.date(byAdding: .year, value: -35, to: Date())!
        let you = PlanPerson(order: 0, name: "A", birthDate: birth, grossAnnualIncome: 100_000, retirementAge: 67)
        var people = [you]
        if couple { people.append(PlanPerson(order: 1, name: "B", birthDate: birth, grossAnnualIncome: 60_000, retirementAge: 65)) }
        let k401 = RetirementAccount(name: "401k", type: .k401, balance: 100_000)
        k401.monthlyEmployeeContribution = 1_000
        k401.monthlyEmployerContribution = 400
        let roth = RetirementAccount(name: "Roth", type: .rothIRA, balance: 30_000)
        roth.monthlyEmployeeContribution = 300
        let brokerage = RetirementAccount(name: "Brokerage", type: .brokerage, balance: 40_000)
        brokerage.costBasis = 30_000
        return RetirementProjector.report(plan: plan, people: people, accounts: [k401, roth, brokerage])
    }

    @Test
    func buildsAReportForASingleFiler() throws {
        let report = try #require(makeReport(couple: false))
        #expect(report.accumulation.totalMonths > 30 * 12)
        #expect(report.accumulation.expected > report.accumulation.currentTotal)
        #expect(report.targetSpending == 80_000)
        #expect(report.low.years.count <= report.expected.years.count + report.expected.totalYears)
        #expect(report.accumulation.low < report.accumulation.expected)
        #expect(report.accumulation.expected < report.accumulation.high)
    }

    @Test
    func buildsAReportForACouple() throws {
        let report = try #require(makeReport(couple: true))
        // The household is measured when the later retirement (age 67) is reached.
        #expect(report.accumulation.totalMonths > 30 * 12)
        #expect(report.targetSpending == 128_000)
        #expect(report.expected.totalYears > 0)
    }

    @Test
    func needsSomethingWhenTheGoalIsBeyondTheSavings() throws {
        let report = try #require(makeReport(couple: false))
        if !report.expected.isFullyFunded {
            let needed = try #require(report.neededAtRetirement)
            #expect(needed > report.accumulation.expected)
            #expect((report.extraMonthlyNeeded ?? 0) > 0)
        }
    }

    @Test
    func noAccountsMeansNoSavingsNeededEstimate() throws {
        let plan = RetirementPlan()
        plan.isSetupComplete = true
        let person = PlanPerson(order: 0, grossAnnualIncome: 100_000)
        let report = try #require(RetirementProjector.report(plan: plan, people: [person], accounts: []))
        #expect(report.neededAtRetirement == nil)
        #expect(!report.expected.isFullyFunded)
    }
}
