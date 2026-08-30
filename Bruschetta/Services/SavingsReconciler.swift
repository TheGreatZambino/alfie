import Foundation
import SwiftData

/// Once a pay period closes, pulls any discretionary overspend for that period out of the cash Savings account.
enum SavingsReconciler {
    static let cashAccountName = "Savings"

    static func reconcile(income: Income?, bills: [Bill], transactions: [Transaction], savingsAccounts: [SavingsAccount], context: ModelContext) {
        guard let income else { return }
        guard let savings = savingsAccounts.first(where: { $0.name == cashAccountName }) else { return }

        let previousPeriod = PayPeriodCalculator.previousPayPeriods(nextPayDate: income.nextPayDate, cadence: income.cadence, count: 1).first
        guard let previousPeriod else { return }

        if let lastReconciled = savings.lastReconciledPeriodEnd, lastReconciled >= previousPeriod.end {
            return
        }

        let billAllocation = bills.filter { $0.isActive }.reduce(0) { $0 + $1.allocationAmount }
        let periodSpending = transactions
            .filter { $0.date >= previousPeriod.start && $0.date <= previousPeriod.end }
            .reduce(0) { $0 + $1.amount }
        let remaining = income.amountPerPeriod - billAllocation - periodSpending

        if remaining < 0 {
            savings.balance += remaining
        }
        savings.lastReconciledPeriodEnd = previousPeriod.end
        try? context.save()
    }
}
