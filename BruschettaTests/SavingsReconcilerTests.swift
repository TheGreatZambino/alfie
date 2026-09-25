import Testing
import Foundation
import SwiftData
@testable import Bruschetta

@MainActor
struct SavingsReconcilerTests {
    private let cal = Calendar.current

    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// A `nextPayDate` two cadence periods out from "today" so the *previous* pay period
    /// (the one `reconcile` acts on) is a fully-closed period ending before today.
    private func biweeklyNextPayDate() -> Date {
        cal.date(byAdding: .day, value: 14, to: cal.startOfDay(for: Date()))!
    }

    private func previousPeriod(nextPayDate: Date) -> PayPeriod {
        PayPeriodCalculator.previousPayPeriods(nextPayDate: nextPayDate, cadence: .biweekly, count: 1).first!
    }

    @Test
    func noOpWhenIncomeIsNil() throws {
        let context = try makeContext()
        let savings = SavingsAccount(name: "Savings", balance: 500)
        context.insert(savings)

        SavingsReconciler.reconcile(income: nil, bills: [], transactions: [], savingsAccounts: [savings], context: context)

        #expect(savings.balance == 500)
        #expect(savings.lastReconciledPeriodEnd == nil)
    }

    @Test
    func nonCashAccountWithNoAllocationIsUntouchedButBaselined() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let other = SavingsAccount(name: "Vacation Fund", balance: 200)
        context.insert(income)
        context.insert(other)

        SavingsReconciler.reconcile(income: income, bills: [], transactions: [], savingsAccounts: [other], context: context)

        // No allocation set, so balance doesn't move, but the account is now baselined
        // so a future call doesn't try to backfill from the beginning of time.
        #expect(other.balance == 200)
        #expect(other.lastReconciledPeriodEnd == previousPeriod(nextPayDate: nextPayDate).end)
    }

    @Test
    func accruesAllocationForNonCashAccountOnFirstReconcile() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let period = previousPeriod(nextPayDate: nextPayDate)
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let investments = SavingsAccount(name: "Investments", balance: 1000, allocationPerPaycheck: 150)
        context.insert(income)
        context.insert(investments)

        SavingsReconciler.reconcile(income: income, bills: [], transactions: [], savingsAccounts: [investments], context: context)

        #expect(investments.balance == 1150)
        #expect(investments.lastReconciledPeriodEnd == period.end)
    }

    @Test
    func catchesUpMultipleMissedPeriodsForNonCashAccount() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let periods = PayPeriodCalculator.previousPayPeriods(nextPayDate: nextPayDate, cadence: .biweekly, count: 3)
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        // Already reconciled through the oldest of the three closed periods.
        let investments = SavingsAccount(name: "Investments", balance: 1000, allocationPerPaycheck: 150, lastReconciledPeriodEnd: periods[0].end)
        context.insert(income)
        context.insert(investments)

        SavingsReconciler.reconcile(income: income, bills: [], transactions: [], savingsAccounts: [investments], context: context)

        // Two more periods have closed since the last reconcile: periods[1] and periods[2].
        #expect(investments.balance == 1300)
        #expect(investments.lastReconciledPeriodEnd == periods[2].end)
    }

    @Test
    func skipsAlreadyReconciledPeriod() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let period = previousPeriod(nextPayDate: nextPayDate)
        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let savings = SavingsAccount(name: "Savings", balance: 500, lastReconciledPeriodEnd: period.end)
        context.insert(income)
        context.insert(savings)

        SavingsReconciler.reconcile(income: income, bills: [], transactions: [], savingsAccounts: [savings], context: context)

        #expect(savings.balance == 500)
    }

    @Test
    func pullsOverspendOutOfSavingsWhenPeriodWentNegative() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let period = previousPeriod(nextPayDate: nextPayDate)
        let midPeriodDate = period.start.addingTimeInterval(3600)

        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let bill = Bill(name: "Rent", amount: 800, allocationAmount: 800, dueDay: 1)
        let overspendTransaction = Transaction(amount: 300, date: midPeriodDate)
        let savings = SavingsAccount(name: "Savings", balance: 500)
        context.insert(income)
        context.insert(bill)
        context.insert(overspendTransaction)
        context.insert(savings)

        // remaining = 1000 - 800 (bills) - 300 (spending) = -100
        SavingsReconciler.reconcile(
            income: income,
            bills: [bill],
            transactions: [overspendTransaction],
            savingsAccounts: [savings],
            context: context
        )

        #expect(savings.balance == 400)
        #expect(savings.lastReconciledPeriodEnd == period.end)
    }

    @Test
    func leavesSavingsUntouchedWhenPeriodDidNotOverspend() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let period = previousPeriod(nextPayDate: nextPayDate)
        let midPeriodDate = period.start.addingTimeInterval(3600)

        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let bill = Bill(name: "Rent", amount: 500, allocationAmount: 500, dueDay: 1)
        let transaction = Transaction(amount: 100, date: midPeriodDate)
        let savings = SavingsAccount(name: "Savings", balance: 500)
        context.insert(income)
        context.insert(bill)
        context.insert(transaction)
        context.insert(savings)

        // remaining = 1000 - 500 - 100 = 400 (positive, nothing pulled)
        SavingsReconciler.reconcile(
            income: income,
            bills: [bill],
            transactions: [transaction],
            savingsAccounts: [savings],
            context: context
        )

        #expect(savings.balance == 500)
        #expect(savings.lastReconciledPeriodEnd == period.end)
    }

    @Test
    func ignoresInactiveBillsAndOutOfPeriodTransactions() throws {
        let context = try makeContext()
        let nextPayDate = biweeklyNextPayDate()
        let period = previousPeriod(nextPayDate: nextPayDate)

        let income = Income(amount: 1000, payCadence: .biweekly, nextPayDate: nextPayDate)
        let inactiveBill = Bill(name: "Old Gym", amount: 900, allocationAmount: 900, dueDay: 1, isActive: false)
        // A transaction dated well before this period should not count against it.
        let staleTransaction = Transaction(amount: 900, date: period.start.addingTimeInterval(-1000 * 24 * 3600))
        let savings = SavingsAccount(name: "Savings", balance: 500)
        context.insert(income)
        context.insert(inactiveBill)
        context.insert(staleTransaction)
        context.insert(savings)

        SavingsReconciler.reconcile(
            income: income,
            bills: [inactiveBill],
            transactions: [staleTransaction],
            savingsAccounts: [savings],
            context: context
        )

        // remaining = 1000 - 0 (inactive bill excluded) - 0 (transaction outside period) = 1000, no deduction.
        #expect(savings.balance == 500)
    }
}
