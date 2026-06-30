import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var incomes: [Income]
    @Query private var bills: [Bill]
    @Query private var transactions: [Transaction]

    @StateObject private var viewModel = DashboardViewModel()

    private var income: Income? { incomes.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    BudgetSummaryCard(viewModel: viewModel)

                    BillsDueCard(bills: viewModel.billsDueThisPeriod, period: viewModel.currentPeriod)

                    BillAllocationCard(totalMonthlyBills: viewModel.totalMonthlyBills, allocationPerPaycheck: viewModel.billAllocationPerPaycheck, payCadenceDisplayName: viewModel.payCadenceDisplayName)

                    SpendingByCategoryCard(items: viewModel.spendingByCategory)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .refreshable {
                refresh()
            }
            .onAppear { refresh() }
            .onChange(of: bills) { _, _ in refresh() }
            .onChange(of: transactions) { _, _ in refresh() }
            .onChange(of: incomes) { _, _ in refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next payday is in \(viewModel.daysUntilNextPay) day\(viewModel.daysUntilNextPay == 1 ? "" : "s")")
                .font(.title2.bold())
            Text(viewModel.nextPayDate.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        viewModel.refresh(income: income, bills: bills, transactions: transactions)
    }
}

private struct BudgetSummaryCard: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budget Summary")
                .font(.headline)

            row(label: "Income this period", value: viewModel.incomeForPeriod, color: .primary)
            row(label: "Bills allocation", value: -viewModel.billAllocationPerPaycheck, color: .red)
            row(label: "Savings allocation", value: -viewModel.savingsAllocation, color: .appAccent)
            row(label: "Spending", value: -viewModel.totalSpending, color: .red)

            Divider()

            HStack {
                Text("Remaining")
                    .font(.headline)
                Spacer()
                Text(viewModel.remaining, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(viewModel.remaining >= 0 ? Color.appAccent : .red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func row(label: String, value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value, format: .currency(code: "USD"))
                .foregroundStyle(color)
        }
        .font(.subheadline)
    }
}

private struct BillsDueCard: View {
    let bills: [Bill]
    let period: PayPeriod?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bills Due This Period")
                .font(.headline)

            if bills.isEmpty {
                Text("No bills due this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(bills) { bill in
                    HStack {
                        Image(systemName: isPast(bill) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isPast(bill) ? Color.appAccent : .secondary)
                        VStack(alignment: .leading) {
                            Text(bill.name)
                            Text("Due \(dueDateText(for: bill))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bill.amount, format: .currency(code: "USD"))
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func dueDate(for bill: Bill) -> Date {
        guard let period else { return Date() }
        let cal = Calendar.current
        for anchor in [period.start, period.end] {
            var comps = cal.dateComponents([.year, .month], from: anchor)
            comps.day = bill.dueDay
            if let date = cal.date(from: comps), date >= period.start && date <= period.end {
                return date
            }
        }
        var comps = cal.dateComponents([.year, .month], from: period.start)
        comps.day = bill.dueDay
        return cal.date(from: comps) ?? period.start
    }

    private func dueDateText(for bill: Bill) -> String {
        dueDate(for: bill).formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private func isPast(_ bill: Bill) -> Bool {
        dueDate(for: bill) < Calendar.current.startOfDay(for: Date())
    }
}

private struct BillAllocationCard: View {
    let totalMonthlyBills: Double
    let allocationPerPaycheck: Double
    let payCadenceDisplayName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Total Monthly Bills")
                .font(.headline)

            HStack {
                Text("Monthly Total")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(totalMonthlyBills, format: .currency(code: "USD"))
                    .font(.title3.bold())
            }

            Divider()

            HStack {
                Text("\(payCadenceDisplayName) allocation")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(allocationPerPaycheck, format: .currency(code: "USD"))
                    .font(.title3.bold())
                    .foregroundStyle(Color.appAccent)
            }
        }
        .font(.subheadline)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

private struct SpendingByCategoryCard: View {
    let items: [(category: Category, amount: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            if items.isEmpty {
                Text("No spending recorded this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(items, id: \.category.name) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.category.name)
                        )
                        .foregroundStyle(Color(hex: item.category.colorHex))
                    }
                }
                .frame(height: CGFloat(items.count) * 36 + 20)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
