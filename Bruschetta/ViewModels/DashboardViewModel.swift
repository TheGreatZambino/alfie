import Foundation
import SwiftData
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var daysUntilNextPay: Int = 0
    @Published var nextPayDate: Date = Date()
    @Published var incomeForPeriod: Double = 0
    @Published var billsDueThisPeriod: [Bill] = []
    @Published var currentPeriod: PayPeriod?
    @Published var totalBillsDue: Double = 0
    @Published var totalMonthlyBills: Double = 0
    @Published var billAllocationPerPaycheck: Double = 0
    @Published var savingsAllocation: Double = 0
    @Published var payCadenceDisplayName: String = ""
    @Published var totalSpending: Double = 0
    @Published var remaining: Double = 0
    @Published var spendingByCategory: [(category: Category, amount: Double)] = []

    func refresh(income: Income?, bills: [Bill], transactions: [Transaction], savingsAccounts: [SavingsAccount] = []) {
        guard let income else {
            daysUntilNextPay = 0
            incomeForPeriod = 0
            billsDueThisPeriod = []
            currentPeriod = nil
            totalBillsDue = 0
            totalMonthlyBills = 0
            billAllocationPerPaycheck = 0
            savingsAllocation = 0
            payCadenceDisplayName = ""
            totalSpending = 0
            remaining = 0
            spendingByCategory = []
            return
        }

        let cadence = income.cadence
        payCadenceDisplayName = cadence.displayName
        let period = PayPeriodCalculator.currentPayPeriod(nextPayDate: income.nextPayDate, cadence: cadence)
        currentPeriod = period

        nextPayDate = period.end.addingTimeInterval(1)
        daysUntilNextPay = PayPeriodCalculator.daysUntilNextPay(nextPayDate: income.nextPayDate, cadence: cadence)
        incomeForPeriod = income.amountPerPeriod

        billsDueThisPeriod = bills.filter { $0.isActive && period.contains(day: $0.dueDay) }
        totalBillsDue = billsDueThisPeriod.reduce(0) { $0 + $1.amount }

        let activeBills = bills.filter { $0.isActive && $0.category?.includeInOverview != false }
        totalMonthlyBills = activeBills.reduce(0) { $0 + $1.amount }
        let savingsAccountAllocation = savingsAccounts.reduce(0) { $0 + $1.allocationPerPaycheck }
        billAllocationPerPaycheck = activeBills.reduce(0) { $0 + $1.allocationAmount } + savingsAccountAllocation
        savingsAllocation = activeBills
            .filter { $0.category?.isSavingsOrInvesting == true }
            .reduce(0) { $0 + $1.allocationAmount } + savingsAccountAllocation

        let periodTransactions = transactions.filter {
            $0.date >= period.start && $0.date <= period.end && $0.category?.includeInOverview != false
        }
        totalSpending = periodTransactions.reduce(0) { $0 + $1.amount }

        remaining = incomeForPeriod - billAllocationPerPaycheck - totalSpending

        var grouped: [ObjectIdentifier: (category: Category, amount: Double)] = [:]
        for t in periodTransactions {
            guard let category = t.category else { continue }
            let key = ObjectIdentifier(category)
            grouped[key, default: (category, 0)].amount += t.amount
        }
        spendingByCategory = grouped.values.sorted { $0.amount > $1.amount }
    }
}
