import Foundation

struct DrawdownPerson: Equatable {
    var birthYear: Int
    /// Age at the start of the first retirement year.
    var ageAtStart: Int
    var claimingAge: Int
    /// Monthly Social Security benefit at full retirement age.
    var piaAtFRA: Double
}

struct DrawdownPool: Equatable {
    var balance: Double
    /// Cost basis, used only for the taxable pool.
    var basis: Double = 0
    var stockFraction: Double

    func scaled(by factor: Double) -> DrawdownPool {
        DrawdownPool(balance: balance * factor, basis: basis * factor, stockFraction: stockFraction)
    }
}

struct DrawdownInput: Equatable {
    var people: [DrawdownPerson]
    /// One pre-tax pool per person, in the same order as `people`.
    var preTax: [DrawdownPool]
    var roth: DrawdownPool
    var taxable: DrawdownPool
    /// Spending wanted each year after taxes, in today's dollars.
    var annualSpending: Double
    var planToAge: Int
    var stateTaxRate: Double
    var assumptions: ProjectionAssumptions
    var shift: Double = 0
    var taxData: TaxYearData = .current

    func scaled(by factor: Double) -> DrawdownInput {
        var copy = self
        copy.preTax = preTax.map { $0.scaled(by: factor) }
        copy.roth = roth.scaled(by: factor)
        copy.taxable = taxable.scaled(by: factor)
        return copy
    }

    var startingBalance: Double {
        preTax.reduce(0) { $0 + $1.balance } + roth.balance + taxable.balance
    }
}

struct DrawdownYear: Identifiable, Equatable {
    /// Age of the first person.
    let age: Int
    let socialSecurity: Double
    let taxableWithdrawal: Double
    let preTaxWithdrawal: Double
    let rothWithdrawal: Double
    let federalTax: Double
    let stateTax: Double
    let penalty: Double
    /// Spendable income after taxes and penalties.
    let netIncome: Double
    let endingBalance: Double

    var id: Int { age }
    var totalTaxes: Double { federalTax + stateTax + penalty }
    var grossIncome: Double { socialSecurity + taxableWithdrawal + preTaxWithdrawal + rothWithdrawal }
}

struct DrawdownResult: Equatable {
    let years: [DrawdownYear]
    let totalYears: Int
    /// Age of the first person in the first year the target could not be fully funded.
    let firstShortfallAge: Int?

    var isFullyFunded: Bool { firstShortfallAge == nil }

    var fundedFraction: Double {
        guard totalYears > 0 else { return 1 }
        if isFullyFunded { return 1 }
        return Double(max(0, years.count - 1)) / Double(totalYears)
    }
}

/// Simulates retirement year by year in today's dollars. Each year it takes required
/// distributions, adds Social Security, then withdraws from taxable accounts, then pre-tax,
/// then Roth until after-tax income reaches the spending target. Any surplus (for example from
/// required distributions) is reinvested in the taxable account.
///
/// Simplifications are listed in the app's Sources screen: taxes use current-year tables with
/// no inflation indexing changes, investment income is taxed only when sold, and a couple
/// stays married filing jointly for the whole plan.
enum DrawdownSimulator {
    /// Pre-tax withdrawals before this age pay the 10% additional tax. The real cutoff is 59½.
    static let penaltyFreeAge = 59
    static let earlyWithdrawalRate = 0.10

    private struct Draw {
        var taxable = 0.0
        var preTax: [Double]
        var roth = 0.0
    }

    private struct Evaluation {
        var net: Double
        var federal: Double
        var state: Double
        var penalty: Double
    }

    static func run(_ input: DrawdownInput) -> DrawdownResult {
        let people = input.people
        guard !people.isEmpty else { return DrawdownResult(years: [], totalYears: 0, firstShortfallAge: nil) }

        var preTax = input.preTax
        var roth = input.roth
        var taxable = input.taxable
        let status: FilingStatus = people.count > 1 ? .marriedJoint : .single
        let target = input.annualSpending

        let youngest = people.map(\.ageAtStart).min() ?? 0
        let totalYears = max(0, input.planToAge - youngest)
        var years: [DrawdownYear] = []
        var shortfallAge: Int?

        func growth(_ pool: DrawdownPool) -> Double {
            1 + RetirementProjector.blendedReturn(stockFraction: pool.stockFraction, assumptions: input.assumptions, shift: input.shift)
        }

        for yearIndex in 0..<totalYears {
            let ages = people.map { $0.ageAtStart + yearIndex }

            var socialSecurity = 0.0
            for (index, person) in people.enumerated() where ages[index] >= person.claimingAge {
                socialSecurity += SocialSecurityCalculator.monthlyBenefit(
                    piaAtFRA: person.piaAtFRA, claimAge: person.claimingAge, birthYear: person.birthYear
                ) * 12
            }

            var required = [Double](repeating: 0, count: people.count)
            for (index, person) in people.enumerated() where ages[index] >= RequiredDistributions.startAge(birthYear: person.birthYear) {
                required[index] = min(preTax[index].balance, RequiredDistributions.requiredDistribution(balance: preTax[index].balance, age: ages[index]))
            }

            let gainFraction = taxable.balance > 0 ? max(0, 1 - taxable.basis / taxable.balance) : 0
            let agedCount = ages.filter { $0 >= 65 }.count

            func evaluate(_ draw: Draw) -> Evaluation {
                let ordinary = draw.preTax.reduce(0, +)
                let gains = draw.taxable * gainFraction
                let federal = FederalTaxCalculator.compute(
                    socialSecurity: socialSecurity, ordinaryIncome: ordinary, longTermGains: gains,
                    status: status, agedCount: agedCount, data: input.taxData
                ).federalTax
                let state = input.stateTaxRate * (ordinary + gains)
                var penalty = 0.0
                for (index, amount) in draw.preTax.enumerated() where ages[index] < penaltyFreeAge {
                    penalty += earlyWithdrawalRate * amount
                }
                let cash = socialSecurity + ordinary + draw.taxable + draw.roth
                return Evaluation(net: cash - federal - state - penalty, federal: federal, state: state, penalty: penalty)
            }

            var draw = Draw(preTax: required)
            var evaluation = evaluate(draw)

            /// Takes from one source until the target is met, or all of it if that isn't enough.
            func fill(available: Double, apply: (inout Draw, Double) -> Void) {
                guard evaluation.net < target - 0.005, available > 0 else { return }
                var all = draw
                apply(&all, available)
                if evaluate(all).net <= target {
                    draw = all
                    evaluation = evaluate(draw)
                    return
                }
                var low = 0.0
                var high = available
                for _ in 0..<60 {
                    let mid = (low + high) / 2
                    var trial = draw
                    apply(&trial, mid)
                    if evaluate(trial).net < target { low = mid } else { high = mid }
                }
                apply(&draw, high)
                evaluation = evaluate(draw)
            }

            fill(available: taxable.balance) { $0.taxable += $1 }

            // Older owners first, since their pre-tax withdrawals avoid the early-withdrawal tax.
            for index in people.indices.sorted(by: { ages[$0] > ages[$1] }) {
                fill(available: preTax[index].balance - required[index]) { $0.preTax[index] += $1 }
            }

            fill(available: roth.balance) { $0.roth += $1 }

            let funded = evaluation.net >= target - 0.5
            if !funded && shortfallAge == nil { shortfallAge = ages[0] }

            // Reinvest any surplus after taxes in the taxable account.
            if evaluation.net > target + 0.005 {
                let surplus = evaluation.net - target
                taxable.balance += surplus
                taxable.basis += surplus
            }

            // Apply withdrawals.
            if draw.taxable > 0, taxable.balance > 0 {
                let fraction = min(1, draw.taxable / taxable.balance)
                taxable.basis -= taxable.basis * fraction
            }
            taxable.balance = max(0, taxable.balance - draw.taxable)
            for index in preTax.indices { preTax[index].balance = max(0, preTax[index].balance - draw.preTax[index]) }
            roth.balance = max(0, roth.balance - draw.roth)

            // Grow what's left over the year.
            taxable.balance *= growth(taxable)
            roth.balance *= growth(roth)
            for index in preTax.indices { preTax[index].balance *= growth(preTax[index]) }

            years.append(DrawdownYear(
                age: ages[0],
                socialSecurity: socialSecurity,
                taxableWithdrawal: draw.taxable,
                preTaxWithdrawal: draw.preTax.reduce(0, +),
                rothWithdrawal: draw.roth,
                federalTax: evaluation.federal,
                stateTax: evaluation.state,
                penalty: evaluation.penalty,
                netIncome: evaluation.net,
                endingBalance: taxable.balance + roth.balance + preTax.reduce(0) { $0 + $1.balance }
            ))

            if !funded { break }
        }

        return DrawdownResult(years: years, totalYears: totalYears, firstShortfallAge: shortfallAge)
    }
}
