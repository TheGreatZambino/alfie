import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Query private var incomes: [Income]
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var mode: TrendsMode = .payPeriod
    @State private var showAddTransaction = false

    private var income: Income? { incomes.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("View", selection: $mode) {
                        ForEach(TrendsMode.allCases) { m in
                            Text(m.label).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if let income {
                        let periods = buildPeriods(income: income)
                        let data = buildData(periods: periods)

                        SpendingTrendChart(data: data, mode: mode)
                            .padding(.horizontal)

                        Divider()

                        ForEach(data.reversed()) { bucket in
                            PeriodBucketRow(bucket: bucket, mode: mode)
                        }
                        .padding(.horizontal)
                    } else {
                        ContentUnavailableView(
                            "No Income Set",
                            systemImage: "chart.bar",
                            description: Text("Set up your income in Settings to see spending trends.")
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Trends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
        }
    }

    private func buildPeriods(income: Income) -> [PayPeriod] {
        switch mode {
        case .payPeriod:
            let current = PayPeriodCalculator.currentPayPeriod(nextPayDate: income.nextPayDate, cadence: income.cadence)
            // Generate enough history to cover all transactions, capped at 24 periods
            let past = PayPeriodCalculator.previousPayPeriods(nextPayDate: income.nextPayDate, cadence: income.cadence, count: 24)
            let all = past + [current]
            return filterToRelevant(all)
        case .monthly:
            let all = PayPeriodCalculator.calendarMonths(count: 24)
            return filterToRelevant(all)
        }
    }

    /// Keeps only periods that contain at least one transaction, plus the current period
    /// and one period before the earliest transaction (so there's always context).
    /// If there are no transactions at all, returns just the previous period + current.
    private func filterToRelevant(_ periods: [PayPeriod]) -> [PayPeriod] {
        guard !periods.isEmpty else { return periods }
        let current = periods.last!

        let txnDates = transactions.map(\.date)
        guard let earliest = txnDates.min() else {
            // No transactions — show one prior period + current
            let prior = periods.dropLast().last
            return [prior, current].compactMap { $0 }
        }

        // Find the first period that contains or precedes the earliest transaction
        let firstRelevantIndex = periods.firstIndex(where: { $0.end >= earliest }) ?? 0
        // Include one period before that for context, if available
        let startIndex = max(0, firstRelevantIndex - 1)
        return Array(periods[startIndex...])
    }

    private func buildData(periods: [PayPeriod]) -> [SpendingBucket] {
        periods.map { period in
            let periodTxns = transactions.filter { $0.date >= period.start && $0.date <= period.end }
            let total = periodTxns.reduce(0) { $0 + $1.amount }

            var byCategory: [String: Double] = [:]
            for t in periodTxns {
                let name = t.category?.name ?? "Uncategorized"
                byCategory[name, default: 0] += t.amount
            }
            let breakdown = byCategory
                .map { CategorySlice(name: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }

            return SpendingBucket(period: period, total: total, breakdown: breakdown)
        }
    }
}

// MARK: - Supporting types

enum TrendsMode: String, CaseIterable, Identifiable {
    case payPeriod, monthly
    var id: Self { self }
    var label: String {
        switch self {
        case .payPeriod: return "Pay Periods"
        case .monthly:   return "Monthly"
        }
    }
}

struct SpendingBucket: Identifiable {
    let id = UUID()
    let period: PayPeriod
    let total: Double
    let breakdown: [CategorySlice]
}

struct CategorySlice: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
}

// MARK: - Chart

private struct SpendingTrendChart: View {
    let data: [SpendingBucket]
    let mode: TrendsMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Spending Over Time")
                .font(.headline)

            Chart(data) { bucket in
                BarMark(
                    x: .value("Period", shortLabel(for: bucket.period, mode: mode)),
                    y: .value("Spent", bucket.total)
                )
                .foregroundStyle(Color.appAccent)
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(format: .currency(code: "USD"))
            }
            .frame(height: 180)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func shortLabel(for period: PayPeriod, mode: TrendsMode) -> String {
        switch mode {
        case .payPeriod:
            let fmt = Date.FormatStyle().month(.twoDigits).day(.twoDigits)
            return period.start.formatted(fmt)
        case .monthly:
            return period.start.formatted(.dateTime.month(.abbreviated))
        }
    }
}

// MARK: - Period row

private struct PeriodBucketRow: View {
    let bucket: SpendingBucket
    let mode: TrendsMode

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rangeLabel)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text(periodSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(bucket.total, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                        .foregroundStyle(Color.appAccent)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if expanded && !bucket.breakdown.isEmpty {
                Divider()
                    .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(bucket.breakdown) { slice in
                        HStack {
                            Text(slice.name)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(slice.amount, format: .currency(code: "USD"))
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if slice.id != bucket.breakdown.last?.id {
                            Divider().padding(.horizontal)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if expanded && bucket.breakdown.isEmpty {
                Text("No spending recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .transition(.opacity)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private var rangeLabel: String {
        let fmt = Date.FormatStyle().month(.twoDigits).day(.twoDigits)
        if mode == .monthly {
            return bucket.period.start.formatted(.dateTime.month(.wide).year())
        }
        return "\(bucket.period.start.formatted(fmt)) – \(bucket.period.end.formatted(fmt))"
    }

    private var periodSubtitle: String {
        if mode == .monthly {
            let fmt = Date.FormatStyle().month(.twoDigits).day(.twoDigits)
            return "\(bucket.period.start.formatted(fmt)) – \(bucket.period.end.formatted(fmt))"
        }
        return "\(bucket.breakdown.count) categor\(bucket.breakdown.count == 1 ? "y" : "ies")"
    }
}
