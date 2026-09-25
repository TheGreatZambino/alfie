import Foundation
import SwiftData

/// Once a pay period closes, accrues each account's per-paycheck allocation into its balance,
/// and pulls any discretionary overspend for that period out of the cash Savings account.
enum SavingsReconciler {
    static let cashAccountName = "Savings"

    /// How many completed pay periods to catch up on a single reconcile call (bounds how far
    /// accrual backfills if the app hasn't been opened in a while).
    private static let maxCatchUpPeriods = 52

    static func reconcile(income: Income?, bills: [Bill], transactions: [Transaction], savingsAccounts: [SavingsAccount], context: ModelContext) {
        guard let income else { return }

        let periods = PayPeriodCalculator.previousPayPeriods(nextPayDate: income.nextPayDate, cadence: income.cadence, count: maxCatchUpPeriods)
        guard let mostRecentPeriod = periods.last else { return }

        var didChange = false

        for account in savingsAccounts {
            let periodsToAccrue: [PayPeriod]
            if let lastReconciled = account.lastReconciledPeriodEnd {
                periodsToAccrue = periods.filter { $0.end > lastReconciled }
            } else {
                // First time this account is reconciled: only credit the most recently closed
                // period instead of backfilling its whole history.
                periodsToAccrue = [mostRecentPeriod]
            }
            guard !periodsToAccrue.isEmpty else { continue }

            account.balance += Double(periodsToAccrue.count) * account.allocationPerPaycheck

            if account.name == cashAccountName {
                let billAllocation = bills.filter { $0.isActive }.reduce(0) { $0 + $1.allocationAmount }
                let periodSpending = transactions
                    .filter { $0.date >= mostRecentPeriod.start && $0.date <= mostRecentPeriod.end }
                    .reduce(0) { $0 + $1.amount }
                let remaining = income.amountPerPeriod - billAllocation - periodSpending
                if remaining < 0 {
                    account.balance += remaining
                }
            }

            account.lastReconciledPeriodEnd = mostRecentPeriod.end
            didChange = true
        }

        if didChange {
            try? context.save()
        }
    }
}
