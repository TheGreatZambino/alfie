import Foundation

/// Assumptions for a projection. All rates are fractions (0.05 = 5%) and returns are real,
/// meaning after inflation, so results are in today's dollars.
struct ProjectionAssumptions: Equatable {
    var stockRealReturn: Double
    var bondRealReturn: Double

    static let defaults = ProjectionAssumptions(
        stockRealReturn: RetirementPlan.defaultStockReturnPercent / 100,
        bondRealReturn: RetirementPlan.defaultBondReturnPercent / 100
    )
}

/// One account reduced to what the projection needs.
struct ProjectionAccount: Equatable {
    var balance: Double
    /// Employee plus employer contributions per month.
    var monthlyContribution: Double
    /// Share held in stocks, 0 to 1.
    var stockFraction: Double
    /// How many months from now contributions continue. After that the balance only grows.
    var contributionMonths: Int
}

struct ProjectionPoint: Identifiable, Equatable {
    let month: Int
    let balance: Double
    var id: Int { month }
    var years: Double { Double(month) / 12 }
}

enum OnTrackStatus: Equatable {
    case onTrack, close, behind
}

/// A household's savings projected from today to retirement (accumulation only).
struct RetirementOutlook: Equatable {
    let totalMonths: Int
    let currentTotal: Double
    let expected: Double
    let low: Double
    let high: Double
    let expectedSeries: [ProjectionPoint]
    let lowSeries: [ProjectionPoint]
    let highSeries: [ProjectionPoint]
}

/// The projection math. Pure functions with no UI or storage dependencies so every formula can
/// be unit tested against known values.
///
/// Growth compounds monthly at the monthly rate equivalent to the annual real return, and each
/// month's contribution is added at the end of the month. Phase 2 covers accumulation only:
/// Social Security and taxes are not yet included.
enum RetirementProjector {
    /// Low and high scenarios shift every return by this many percentage points (as a fraction).
    /// This is a sensitivity range chosen for the app, not a forecast.
    static let scenarioSpread = 0.02

    /// Used for the "extra savings needed" estimate when there are no accounts yet.
    static let fallbackStockFraction = 0.6

    static func blendedReturn(stockFraction: Double, assumptions: ProjectionAssumptions, shift: Double = 0) -> Double {
        let fraction = min(max(stockFraction, 0), 1)
        let blended = fraction * assumptions.stockRealReturn + (1 - fraction) * assumptions.bondRealReturn
        return max(-0.99, blended + shift)
    }

    static func monthlyRate(fromAnnual annual: Double) -> Double {
        pow(1 + annual, 1.0 / 12) - 1
    }

    /// Balance of one account at the end of each month, from month 0 (today) to `totalMonths`.
    static func monthlyBalances(
        for account: ProjectionAccount,
        assumptions: ProjectionAssumptions,
        totalMonths: Int,
        shift: Double = 0
    ) -> [Double] {
        let rate = monthlyRate(fromAnnual: blendedReturn(stockFraction: account.stockFraction, assumptions: assumptions, shift: shift))
        var balances = [account.balance]
        balances.reserveCapacity(totalMonths + 1)
        var current = account.balance
        for month in 1...max(totalMonths, 1) where month <= totalMonths {
            current = current * (1 + rate)
            if month <= account.contributionMonths { current += account.monthlyContribution }
            balances.append(current)
        }
        return balances
    }

    static func futureValue(
        of account: ProjectionAccount,
        assumptions: ProjectionAssumptions,
        totalMonths: Int,
        shift: Double = 0
    ) -> Double {
        monthlyBalances(for: account, assumptions: assumptions, totalMonths: totalMonths, shift: shift).last ?? account.balance
    }

    /// Household balance sampled once a year, plus the final month.
    static func series(
        for accounts: [ProjectionAccount],
        assumptions: ProjectionAssumptions,
        totalMonths: Int,
        shift: Double = 0
    ) -> [ProjectionPoint] {
        var totals = [Double](repeating: 0, count: totalMonths + 1)
        for account in accounts {
            let balances = monthlyBalances(for: account, assumptions: assumptions, totalMonths: totalMonths, shift: shift)
            for month in 0...totalMonths { totals[month] += balances[month] }
        }
        var months = Array(stride(from: 0, through: totalMonths, by: 12))
        if months.last != totalMonths { months.append(totalMonths) }
        return months.map { ProjectionPoint(month: $0, balance: totals[$0]) }
    }

    /// Level monthly contribution (added at month end) that grows to `shortfall` over `months`
    /// at the given annual return. Nil when there is nothing to close or no time left.
    static func monthlyContributionNeeded(shortfall: Double, annualReturn: Double, months: Int) -> Double? {
        guard shortfall > 0, months > 0 else { return nil }
        let rate = monthlyRate(fromAnnual: annualReturn)
        if abs(rate) < 1e-12 { return shortfall / Double(months) }
        return shortfall * rate / (pow(1 + rate, Double(months)) - 1)
    }

    static func outlook(
        accounts: [ProjectionAccount],
        assumptions: ProjectionAssumptions,
        totalMonths: Int
    ) -> RetirementOutlook {
        let expectedSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths)
        let lowSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths, shift: -scenarioSpread)
        let highSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths, shift: scenarioSpread)
        return RetirementOutlook(
            totalMonths: totalMonths,
            currentTotal: accounts.reduce(0) { $0 + $1.balance },
            expected: expectedSeries.last?.balance ?? 0,
            low: lowSeries.last?.balance ?? 0,
            high: highSeries.last?.balance ?? 0,
            expectedSeries: expectedSeries,
            lowSeries: lowSeries,
            highSeries: highSeries
        )
    }

    /// Approximate return on new savings: the balance-weighted blend of the accounts, or a
    /// 60/40 mix when there are none.
    static func weightedReturn(of accounts: [ProjectionAccount], assumptions: ProjectionAssumptions) -> Double {
        if accounts.isEmpty {
            return blendedReturn(stockFraction: fallbackStockFraction, assumptions: assumptions)
        }
        let totalBalance = accounts.reduce(0) { $0 + $1.balance }
        if totalBalance > 0 {
            return accounts.reduce(0) {
                $0 + blendedReturn(stockFraction: $1.stockFraction, assumptions: assumptions) * $1.balance
            } / totalBalance
        }
        return accounts.reduce(0) {
            $0 + blendedReturn(stockFraction: $1.stockFraction, assumptions: assumptions)
        } / Double(accounts.count)
    }
}

// MARK: - Full report

/// Everything the Retirement tab shows: savings growth to retirement, the retirement-income
/// simulation in three return scenarios, and how much more would be needed.
struct RetirementReport {
    let accumulation: RetirementOutlook
    let planToAge: Int
    /// Yearly spending wanted after taxes, in today's dollars.
    let targetSpending: Double
    let expected: DrawdownResult
    let low: DrawdownResult
    let high: DrawdownResult
    /// Savings at retirement that would fully fund the plan, scaling every account up or down
    /// together. Nil when none is found or there are no balances.
    let neededAtRetirement: Double?
    /// Extra savings per month, on top of today's, that would close the gap to `neededAtRetirement`.
    let extraMonthlyNeeded: Double?

    var status: OnTrackStatus {
        if expected.isFullyFunded { return .onTrack }
        if let age = expected.firstShortfallAge, age >= planToAge - 5 { return .close }
        return .behind
    }

    var firstYear: DrawdownYear? { expected.years.first }
}

extension RetirementProjector {
    static func report(plan: RetirementPlan, people: [PlanPerson], accounts: [RetirementAccount]) -> RetirementReport? {
        let active = Array(people.sorted { $0.order < $1.order }.prefix(plan.isCouple ? 2 : 1))
        guard let first = active.first else { return nil }

        let assumptions = plan.assumptions
        let totalMonths = active.map(\.monthsToRetirement).max() ?? 0
        let combinedGross = active.reduce(0) { $0 + $1.grossAnnualIncome }
        let spending = plan.targetAnnualIncome(combinedGross: combinedGross)

        let projectionAccounts = accounts.map { account -> ProjectionAccount in
            let owner = active.first(where: { $0.order == account.ownerOrder }) ?? first
            return ProjectionAccount(
                balance: account.balance,
                monthlyContribution: account.monthlyContribution,
                stockFraction: account.stockAllocationPercent / 100,
                contributionMonths: owner.monthsToRetirement
            )
        }
        let accumulation = outlook(accounts: projectionAccounts, assumptions: assumptions, totalMonths: totalMonths)

        let drawdownPeople = active.map { person in
            DrawdownPerson(
                birthYear: person.birthYear,
                ageAtStart: (person.ageInMonths + totalMonths) / 12,
                claimingAge: person.claimingAge,
                piaAtFRA: person.socialSecurityMonthlyAtFRA > 0
                    ? person.socialSecurityMonthlyAtFRA
                    : SocialSecurityCalculator.estimatedPIA(annualGross: person.grossAnnualIncome)
            )
        }

        func input(shift: Double) -> DrawdownInput {
            // Group accounts into pools at the moment the household retires.
            var preTaxBalance = [Double](repeating: 0, count: active.count)
            var preTaxStock = [Double](repeating: 0, count: active.count)
            var rothBalance = 0.0, rothStock = 0.0
            var taxableBalance = 0.0, taxableStock = 0.0, taxableBasis = 0.0

            for (account, projection) in zip(accounts, projectionAccounts) {
                let final = futureValue(of: projection, assumptions: assumptions, totalMonths: totalMonths, shift: shift)
                let weightedStock = final * projection.stockFraction
                switch account.bucket {
                case .preTax:
                    let index = active.firstIndex(where: { $0.order == account.ownerOrder }) ?? 0
                    preTaxBalance[index] += final
                    preTaxStock[index] += weightedStock
                case .roth:
                    rothBalance += final
                    rothStock += weightedStock
                case .taxable:
                    taxableBalance += final
                    taxableStock += weightedStock
                    let paidIn = (account.costBasis ?? account.balance) + account.monthlyContribution * Double(projection.contributionMonths)
                    taxableBasis += min(final, paidIn)
                }
            }

            func pool(_ balance: Double, _ stock: Double, basis: Double = 0) -> DrawdownPool {
                DrawdownPool(
                    balance: balance,
                    basis: basis,
                    stockFraction: balance > 0 ? stock / balance : fallbackStockFraction
                )
            }
            return DrawdownInput(
                people: drawdownPeople,
                preTax: active.indices.map { pool(preTaxBalance[$0], preTaxStock[$0]) },
                roth: pool(rothBalance, rothStock),
                taxable: pool(taxableBalance, taxableStock, basis: taxableBasis),
                annualSpending: spending,
                planToAge: plan.planToAge,
                stateTaxRate: plan.stateTaxRatePercent / 100,
                assumptions: assumptions,
                shift: shift
            )
        }

        let expectedInput = input(shift: 0)
        let expected = DrawdownSimulator.run(expectedInput)
        let low = DrawdownSimulator.run(input(shift: -scenarioSpread))
        let high = DrawdownSimulator.run(input(shift: scenarioSpread))

        let needed = savingsNeeded(for: expectedInput)
        let shortfall = max(0, (needed ?? 0) - accumulation.expected)
        let extra = needed == nil ? nil : monthlyContributionNeeded(
            shortfall: shortfall,
            annualReturn: weightedReturn(of: projectionAccounts, assumptions: assumptions),
            months: totalMonths
        )

        return RetirementReport(
            accumulation: accumulation,
            planToAge: plan.planToAge,
            targetSpending: spending,
            expected: expected,
            low: low,
            high: high,
            neededAtRetirement: needed,
            extraMonthlyNeeded: extra
        )
    }

    /// The smallest total savings at retirement that fully funds the plan, found by scaling all
    /// pools together. Zero if Social Security alone covers the goal; nil if no balances exist or
    /// even 50 times the projected savings isn't enough.
    static func savingsNeeded(for input: DrawdownInput) -> Double? {
        let start = input.startingBalance
        guard start > 0 else { return nil }
        if DrawdownSimulator.run(input.scaled(by: 0)).isFullyFunded { return 0 }
        let maxScale = 50.0
        guard DrawdownSimulator.run(input.scaled(by: maxScale)).isFullyFunded else { return nil }
        var low = 0.0
        var high = maxScale
        for _ in 0..<40 {
            let mid = (low + high) / 2
            if DrawdownSimulator.run(input.scaled(by: mid)).isFullyFunded { high = mid } else { low = mid }
        }
        return high * start
    }
}
