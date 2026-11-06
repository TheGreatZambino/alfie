import Foundation

/// Assumptions for a projection. All rates are fractions (0.05 = 5%) and returns are real,
/// meaning after inflation, so results are in today's dollars.
struct ProjectionAssumptions: Equatable {
    var stockRealReturn: Double
    var bondRealReturn: Double
    var withdrawalRate: Double

    static let defaults = ProjectionAssumptions(
        stockRealReturn: RetirementPlan.defaultStockReturnPercent / 100,
        bondRealReturn: RetirementPlan.defaultBondReturnPercent / 100,
        withdrawalRate: RetirementPlan.defaultWithdrawalRatePercent / 100
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

/// The result of projecting a household's accounts to retirement and comparing the result to
/// the savings needed to fund the income goal.
struct RetirementOutlook: Equatable {
    let totalMonths: Int
    let currentTotal: Double
    let expected: Double
    let low: Double
    let high: Double
    let requiredNestEgg: Double
    let expectedSeries: [ProjectionPoint]
    let lowSeries: [ProjectionPoint]
    let highSeries: [ProjectionPoint]
    /// Extra savings per month, on top of today's, that would close the gap. Nil when there
    /// is no gap or no time left.
    let extraMonthlyNeeded: Double?

    var progress: Double? {
        requiredNestEgg > 0 ? expected / requiredNestEgg : nil
    }

    var status: OnTrackStatus? {
        progress.map(RetirementProjector.status(forProgress:))
    }

    var gap: Double {
        max(0, requiredNestEgg - expected)
    }
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

    /// Savings needed to fund an income at a given withdrawal rate: income divided by the rate.
    static func requiredNestEgg(targetAnnualIncome: Double, withdrawalRate: Double) -> Double {
        guard withdrawalRate > 0 else { return 0 }
        return targetAnnualIncome / withdrawalRate
    }

    /// Level monthly contribution (added at month end) that grows to `shortfall` over `months`
    /// at the given annual return. Nil when there is nothing to close or no time left.
    static func monthlyContributionNeeded(shortfall: Double, annualReturn: Double, months: Int) -> Double? {
        guard shortfall > 0, months > 0 else { return nil }
        let rate = monthlyRate(fromAnnual: annualReturn)
        if abs(rate) < 1e-12 { return shortfall / Double(months) }
        return shortfall * rate / (pow(1 + rate, Double(months)) - 1)
    }

    /// At 100% or more of the needed savings the household is on track, 80% to 100% is close,
    /// and below 80% is behind. The cutoffs are the app's own, chosen for the status label.
    static func status(forProgress progress: Double) -> OnTrackStatus {
        if progress >= 1 { return .onTrack }
        if progress >= 0.8 { return .close }
        return .behind
    }

    static func outlook(
        accounts: [ProjectionAccount],
        assumptions: ProjectionAssumptions,
        totalMonths: Int,
        targetAnnualIncome: Double
    ) -> RetirementOutlook {
        let expectedSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths)
        let lowSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths, shift: -scenarioSpread)
        let highSeries = series(for: accounts, assumptions: assumptions, totalMonths: totalMonths, shift: scenarioSpread)
        let expected = expectedSeries.last?.balance ?? 0
        let required = requiredNestEgg(targetAnnualIncome: targetAnnualIncome, withdrawalRate: assumptions.withdrawalRate)

        // Approximate the return on new savings with the balance-weighted blend of the accounts.
        let totalBalance = accounts.reduce(0) { $0 + $1.balance }
        let weightedReturn: Double
        if accounts.isEmpty {
            weightedReturn = blendedReturn(stockFraction: fallbackStockFraction, assumptions: assumptions)
        } else if totalBalance > 0 {
            weightedReturn = accounts.reduce(0) {
                $0 + blendedReturn(stockFraction: $1.stockFraction, assumptions: assumptions) * $1.balance
            } / totalBalance
        } else {
            weightedReturn = accounts.reduce(0) {
                $0 + blendedReturn(stockFraction: $1.stockFraction, assumptions: assumptions)
            } / Double(accounts.count)
        }

        return RetirementOutlook(
            totalMonths: totalMonths,
            currentTotal: totalBalance,
            expected: expected,
            low: lowSeries.last?.balance ?? 0,
            high: highSeries.last?.balance ?? 0,
            requiredNestEgg: required,
            expectedSeries: expectedSeries,
            lowSeries: lowSeries,
            highSeries: highSeries,
            extraMonthlyNeeded: monthlyContributionNeeded(shortfall: max(0, required - expected), annualReturn: weightedReturn, months: totalMonths)
        )
    }
}

// MARK: - Building from stored models

extension RetirementProjector {
    /// Projects the household's stored accounts. Each account keeps receiving contributions until
    /// its owner retires, and the household is measured when the last person retires.
    static func outlook(plan: RetirementPlan, people: [PlanPerson], accounts: [RetirementAccount]) -> RetirementOutlook? {
        let active = Array(people.sorted { $0.order < $1.order }.prefix(plan.isCouple ? 2 : 1))
        guard let first = active.first else { return nil }

        let totalMonths = active.map(\.monthsToRetirement).max() ?? 0
        let projectionAccounts = accounts.map { account -> ProjectionAccount in
            let owner = active.first(where: { $0.order == account.ownerOrder }) ?? first
            return ProjectionAccount(
                balance: account.balance,
                monthlyContribution: account.monthlyContribution,
                stockFraction: account.stockAllocationPercent / 100,
                contributionMonths: owner.monthsToRetirement
            )
        }
        let combinedGross = active.reduce(0) { $0 + $1.grossAnnualIncome }
        return outlook(
            accounts: projectionAccounts,
            assumptions: plan.assumptions,
            totalMonths: totalMonths,
            targetAnnualIncome: plan.targetAnnualIncome(combinedGross: combinedGross)
        )
    }
}
