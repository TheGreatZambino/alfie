import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var incomes: [Income]
    @Query private var bills: [Bill]
    @Query private var transactions: [Transaction]
    @Query private var savingsAccounts: [SavingsAccount]

    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddTransaction = false
    @State private var showSettings = false
    @State private var didAddTransaction = false
    @State private var navigateToTransactions = false

    private var income: Income? { incomes.first }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 14) {
                        header

                        BalanceCard(viewModel: viewModel)

                        if !savingsAccounts.isEmpty {
                            HStack(spacing: 12) {
                                ForEach(savingsAccounts) { account in
                                    SavingsTile(account: account)
                                }
                            }
                        }

                        BillsThisPeriodCard(bills: viewModel.billsDueThisPeriod, period: viewModel.currentPeriod)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 90)
                }

                Button {
                    showAddTransaction = true
                } label: {
                    Circle()
                        .fill(Color.moneyFill)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color.moneyFill.opacity(0.32), radius: 10, y: 8)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .tint(.money)
            .sheet(isPresented: $showAddTransaction, onDismiss: {
                guard didAddTransaction else { return }
                didAddTransaction = false
                navigateToTransactions = true
            }) {
                AddTransactionView(remaining: viewModel.remaining, onSave: { didAddTransaction = true })
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $navigateToTransactions) {
                TransactionListView()
            }
            .refreshable {
                refresh()
            }
            .onAppear { refresh() }
            .onChange(of: bills) { _, _ in refresh() }
            .onChange(of: transactions) { _, _ in refresh() }
            .onChange(of: incomes) { _, _ in refresh() }
            .onChange(of: savingsAccounts) { _, _ in refresh() }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FINANCES")
                    .eyebrowStyle(color: .money)
                Text(viewModel.daysUntilNextPay <= 1 ? "Payday is tomorrow" : "Payday in \(viewModel.daysUntilNextPay) days")
                    .font(.screenHeadline)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                NavigationLink {
                    TransactionListView()
                } label: {
                    circleButton(systemName: "list.bullet")
                }
                NavigationLink {
                    TrendsView()
                } label: {
                    circleButton(systemName: "chart.bar.xaxis")
                }
                Button {
                    showSettings = true
                } label: {
                    circleButton(systemName: "gearshape")
                }
            }
        }
        .frame(minHeight: 84)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func circleButton(systemName: String) -> some View {
        Circle()
            .fill(Color.card)
            .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
            )
            .frame(width: 36, height: 36)
    }

    private func refresh() {
        viewModel.refresh(income: income, bills: bills, transactions: transactions, savingsAccounts: savingsAccounts)
    }
}

// MARK: - Card 1: Balance

private struct BalanceCard: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LEFT THIS PERIOD")
                .textCase(.uppercase)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.72))

            Text(viewModel.remaining, format: .currency(code: "USD"))
                .font(.heroNumeralScreen)
                .foregroundStyle(.white)

            SegmentedBar(
                segments: [
                    .init(fraction: billsFraction, color: .white.opacity(0.9)),
                    .init(fraction: savingsFraction, color: .white.opacity(0.6)),
                    .init(fraction: spentFraction, color: .white.opacity(0.38)),
                ],
                trackColor: .white.opacity(0.2)
            )

            Text("\(viewModel.incomeForPeriod, format: .currency(code: "USD").precision(.fractionLength(0))) in · \(viewModel.billAllocationPerPaycheck + viewModel.totalSpending, format: .currency(code: "USD").precision(.fractionLength(0))) committed · \(perDayToPayday, format: .currency(code: "USD").precision(.fractionLength(0)))/day to payday")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
        }
        .heroCardStyle(pillar: .moneyFill)
    }

    private var total: Double { max(viewModel.incomeForPeriod, 1) }
    private var billsFraction: Double { (viewModel.billAllocationPerPaycheck - viewModel.savingsAllocation) / total }
    private var savingsFraction: Double { viewModel.savingsAllocation / total }
    private var spentFraction: Double { viewModel.totalSpending / total }

    private var perDayToPayday: Double {
        viewModel.daysUntilNextPay > 0 ? viewModel.remaining / Double(viewModel.daysUntilNextPay) : viewModel.remaining
    }
}

// MARK: - Card 2: Savings/Investments tiles

private struct SavingsTile: View {
    let account: SavingsAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(account.name)
                .font(.system(size: 12))
                .foregroundStyle(Color.inkTertiary)
            Text(account.balance, format: .currency(code: "USD"))
                .font(.cardNumeral)
                .foregroundStyle(Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 22)
    }
}

// MARK: - Card 3: Bills this period

private struct BillsThisPeriodCard: View {
    let bills: [Bill]
    let period: PayPeriod?

    private var unpaidCount: Int { bills.filter { !isPast($0) }.count }
    private var unpaidTotal: Double { bills.filter { !isPast($0) }.reduce(0) { $0 + $1.amount } }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("BILLS THIS PERIOD")
                    .sectionLabelStyle()
                Spacer()
                if !bills.isEmpty {
                    Text("\(unpaidCount) left · \(unpaidTotal, format: .currency(code: "USD").precision(.fractionLength(0)))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                }
            }
            .padding(.bottom, 8)

            if bills.isEmpty {
                HStack(spacing: 12) {
                    IconBadge(systemName: "checkmark.seal.fill", color: .inkTertiary, size: 32)
                    Text("No bills due this period.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(bills.enumerated()), id: \.element.id) { index, bill in
                        billRow(bill)
                        if index < bills.count - 1 {
                            Divider().overlay(Color.hairline).padding(.leading, 46)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private func billRow(_ bill: Bill) -> some View {
        let paid = isPast(bill)
        return HStack(spacing: 12) {
            IconBadge(
                systemName: bill.category?.icon ?? "doc.text.fill",
                color: paid ? .inkTertiary : .money,
                size: 34,
                shape: .roundedSquare(radius: 12)
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name)
                    .font(.rowTitle)
                    .foregroundStyle(paid ? Color.inkTertiary : Color.ink)
                    .strikethrough(paid)
                Text(paid ? "Paid \(dueDateText(for: bill))" : dueInText(for: bill))
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            }

            Spacer()

            Text(bill.amount, format: .currency(code: "USD"))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(paid ? Color.inkQuaternary : Color.ink)
        }
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
        dueDate(for: bill).formatted(.dateTime.month(.abbreviated).day())
    }

    private func dueInText(for bill: Bill) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: dueDate(for: bill)).day ?? 0
        if days <= 0 { return "Due today" }
        if days == 1 { return "Due tomorrow" }
        return "Due in \(days) days"
    }

    private func isPast(_ bill: Bill) -> Bool {
        dueDate(for: bill) < Calendar.current.startOfDay(for: Date())
    }
}
