import SwiftUI
import SwiftData
import WidgetKit

struct OverviewView: View {
    @Binding var selectedTab: AppTab
    let trackedModules: Set<TrackedModule>

    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var workoutGoals: [WorkoutGoals]
    @Query private var incomes: [Income]
    @Query private var bills: [Bill]
    @Query private var savingsAccounts: [SavingsAccount]
    @Query private var transactions: [Transaction]
    @Query private var nutritionEntries: [NutritionEntry]
    @Query private var nutritionGoals: [NutritionGoals]

    @ObservedObject private var health = HealthKitManager.shared
    @StateObject private var viewModel = OverviewViewModel()
    @State private var showSettings = false

    private var income: Income? { incomes.first }

    private var caloriesToday: Double {
        let calendar = Calendar.current
        return nutritionEntries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }
    }

    private var daysToPayday: Int? {
        income.map { PayPeriodCalculator.daysUntilNextPay(nextPayDate: $0.nextPayDate, cadence: $0.cadence) }
    }

    private var scrollContent: some View {
        VStack(spacing: 14) {
            header

            WeekTriadCard(viewModel: viewModel, trackedModules: trackedModules)

            PillarRowsCard(viewModel: viewModel, caloriesToday: caloriesToday, daysToPayday: daysToPayday, trackedModules: trackedModules, selectedTab: $selectedTab)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    private var screenBody: some View {
        ScrollView {
            scrollContent
        }
        .background(Color.paper)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.ink)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .refreshable { refresh() }
        .onAppear { refresh() }
    }

    var body: some View {
        NavigationStack {
            screenBody
                .modifier(RefreshOnChange(sessions: sessions, transactions: transactions, nutritionEntries: nutritionEntries, incomes: incomes, bills: bills, savingsAccounts: savingsAccounts, workoutGoals: workoutGoals, nutritionGoals: nutritionGoals, healthAuthorized: health.isAuthorized, refresh: refresh))
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dateEyebrowText)
                    .eyebrowStyle()
                Text(verdictText)
                    .font(.screenHeadline)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }

            Spacer()

            Button { showSettings = true } label: {
                Circle()
                    .fill(Color.card)
                    .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                    .overlay(
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.inkSecondary)
                    )
                    .frame(width: 36, height: 36)
            }
        }
        .frame(minHeight: 84)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var dateEyebrowText: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()
    }

    private var verdictText: String {
        switch viewModel.overallScore {
        case 80...: return "Strong week"
        case 50..<80: return "Good week so far"
        default: return "Slow week"
        }
    }

    private func refresh() {
        viewModel.refresh(
            sessions: sessions,
            workoutGoals: workoutGoals.first,
            income: income,
            bills: bills,
            transactions: transactions,
            savingsAccounts: savingsAccounts,
            nutritionEntries: nutritionEntries,
            nutritionGoal: nutritionGoals.first,
            health: health
        )
        refreshWidgetSnapshot()
    }

    /// Publishes today's finances and nutrition to the App Group so the home screen widget
    /// (which can't query SwiftData directly) can show them alongside workouts.
    private func refreshWidgetSnapshot() {
        let periodEnd: Date? = income.map {
            PayPeriodCalculator.currentPayPeriod(nextPayDate: $0.nextPayDate, cadence: $0.cadence).end
        }
        let calendar = Calendar.current
        let caloriesToday = nutritionEntries
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.calories }

        WidgetSnapshotStore.update { snapshot in
            snapshot.finance = income != nil
                ? FinanceSnapshot(incomeThisPeriod: viewModel.incomeThisPeriod, remainingThisPeriod: viewModel.remainingThisPeriod, periodEnd: periodEnd)
                : nil
            snapshot.nutrition = NutritionSnapshot(caloriesToday: caloriesToday, calorieGoal: viewModel.calorieGoal)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.homeWidgetKind)
    }
}

/// Isolated into its own ViewModifier so the type checker doesn't have to solve one giant
/// modifier-chain expression alongside the rest of OverviewView's body.
private struct RefreshOnChange: ViewModifier {
    let sessions: [WorkoutSession]
    let transactions: [Transaction]
    let nutritionEntries: [NutritionEntry]
    let incomes: [Income]
    let bills: [Bill]
    let savingsAccounts: [SavingsAccount]
    let workoutGoals: [WorkoutGoals]
    let nutritionGoals: [NutritionGoals]
    let healthAuthorized: Bool
    let refresh: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessions) { _, _ in refresh() }
            .onChange(of: transactions) { _, _ in refresh() }
            .onChange(of: nutritionEntries) { _, _ in refresh() }
            .onChange(of: incomes) { _, _ in refresh() }
            .onChange(of: bills) { _, _ in refresh() }
            .onChange(of: savingsAccounts) { _, _ in refresh() }
            .onChange(of: workoutGoals) { _, _ in refresh() }
            .onChange(of: nutritionGoals) { _, _ in refresh() }
            .onChange(of: healthAuthorized) { _, _ in refresh() }
    }
}

// MARK: - Card 1: Week triad

private struct WeekTriadCard: View {
    @ObservedObject var viewModel: OverviewViewModel
    let trackedModules: Set<TrackedModule>

    private var trackedScores: [Double] {
        var scores: [Double] = []
        if trackedModules.contains(.finance) { scores.append(viewModel.expenseScore) }
        if trackedModules.contains(.workouts) { scores.append(viewModel.workoutScore) }
        if trackedModules.contains(.nutrition) { scores.append(viewModel.calorieScore) }
        return scores
    }

    private var onTrackCount: Int {
        trackedScores.filter { $0 >= 60 }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("THIS WEEK")
                    .sectionLabelStyle()
                Spacer()
                Text("\(onTrackCount) of \(trackedScores.count) on track")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.money)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(Capsule().fill(Color.moneyTint))
            }

            HStack(spacing: 8) {
                if trackedModules.contains(.finance) {
                    TriadColumn(pillar: .money, symbol: "wallet.bifold", progress: viewModel.expenseScore / 100, label: "Money", status: statusText(viewModel.expenseScore))
                }
                if trackedModules.contains(.workouts) {
                    TriadColumn(pillar: .training, symbol: "figure.strengthtraining.traditional", progress: viewModel.workoutScore / 100, label: "Training", status: statusText(viewModel.workoutScore))
                }
                if trackedModules.contains(.nutrition) {
                    TriadColumn(pillar: .food, symbol: "fork.knife", progress: viewModel.calorieScore / 100, label: "Food", status: statusText(viewModel.calorieScore))
                }
            }
        }
        .cardStyle()
    }

    private func statusText(_ score: Double) -> String {
        switch score {
        case 80...: return "Ahead"
        case 50..<80: return "On pace"
        default: return "Behind"
        }
    }
}

private struct TriadColumn: View {
    let pillar: Color
    let symbol: String
    let progress: Double
    let label: String
    let status: String

    var body: some View {
        VStack(spacing: 8) {
            RingGauge(progress: progress, color: pillar, lineWidth: 6, size: 66) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(pillar)
            }
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.ink)
            Text(status)
                .font(.system(size: 12))
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card 2: Pillar rows

private struct PillarRowsCard: View {
    @ObservedObject var viewModel: OverviewViewModel
    let caloriesToday: Double
    let daysToPayday: Int?
    let trackedModules: Set<TrackedModule>
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            if trackedModules.contains(.finance) {
                PillarRow(
                    pillar: .money,
                    label: "MONEY",
                    heroValue: viewModel.remainingThisPeriod.formatted(.currency(code: "USD").precision(.fractionLength(0))),
                    supporting: "left · \(daysToPaydayText)"
                ) {
                    SegmentedBar(segments: moneySegments)
                } action: {
                    selectedTab = .finances
                }

                if trackedModules.contains(.workouts) || trackedModules.contains(.nutrition) {
                    Divider().overlay(Color.hairline)
                }
            }

            if trackedModules.contains(.workouts) {
                PillarRow(
                    pillar: .training,
                    label: "TRAINING",
                    heroValue: "\(viewModel.strengthSessionsThisWeek)",
                    supporting: "of \(viewModel.strengthGoal) sessions · \(viewModel.stepsThisWeek.formatted()) steps"
                ) {
                    WeekGrid(days: viewModel.weekdayCompletion)
                } action: {
                    selectedTab = .workouts
                }

                if trackedModules.contains(.nutrition) {
                    Divider().overlay(Color.hairline)
                }
            }

            if trackedModules.contains(.nutrition) {
                PillarRow(
                    pillar: .food,
                    label: "FOOD",
                    heroValue: "\(max(Int(viewModel.calorieGoal - caloriesToday), 0).formatted())",
                    supporting: "left today · \(viewModel.goodCalorieDays) of 7 on target"
                ) {
                    SegmentedBar(segments: [.init(fraction: foodFraction, color: .food)], trackColor: .foodTint)
                } action: {
                    selectedTab = .nutrition
                }
            }
        }
        .cardStyle()
    }

    private var foodFraction: Double {
        viewModel.calorieGoal > 0 ? min(1, caloriesToday / viewModel.calorieGoal) : 0
    }

    private var daysToPaydayText: String {
        guard let daysToPayday else { return "set up income" }
        if daysToPayday <= 1 { return "payday tomorrow" }
        return "\(daysToPayday) days to payday"
    }

    private var moneySegments: [SegmentedBar.Segment] {
        let total = max(viewModel.incomeThisPeriod, 1)
        let billsFraction = viewModel.billsAllocationThisPeriod / total
        let savingsFraction = viewModel.savingsAllocationThisPeriod / total
        let spentFraction = viewModel.spendingThisPeriod / total
        let remainingFraction = max(1 - billsFraction - savingsFraction - spentFraction, 0)
        return [
            .init(fraction: billsFraction, color: .training),
            .init(fraction: savingsFraction, color: .food),
            .init(fraction: spentFraction, color: Color.ink.opacity(0.22)),
            .init(fraction: remainingFraction, color: .money),
        ]
    }
}

private struct PillarRow<Visual: View>: View {
    let pillar: Color
    let label: String
    let heroValue: String
    let supporting: String
    @ViewBuilder var visual: () -> Visual
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle().fill(pillar).frame(width: 9, height: 9)
                    Text(label)
                        .sectionLabelStyle()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkQuaternary)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(heroValue)
                        .font(.heroNumeralCard)
                        .foregroundStyle(Color.ink)
                    Text(supporting)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.inkSecondary)
                }

                visual()
                    .frame(height: 8)
            }
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

private struct WeekGrid: View {
    let days: [DayCompletion]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(days) { day in
                cell(for: day)
            }
        }
    }

    @ViewBuilder
    private func cell(for day: DayCompletion) -> some View {
        let isFuture = Calendar.current.startOfDay(for: day.date) > Calendar.current.startOfDay(for: Date())

        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(fillColor(for: day, isFuture: isFuture))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isFuture ? Color.ink.opacity(0.14) : .clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            )
            .overlay(icon(for: day, isFuture: isFuture))
            .frame(height: 26)
            .frame(maxWidth: .infinity)
    }

    private func fillColor(for day: DayCompletion, isFuture: Bool) -> Color {
        if day.hasStrength { return .training }
        if day.hasCardio { return Color.training.opacity(0.14) }
        if isFuture { return Color.ink.opacity(0.04) }
        return Color.ink.opacity(0.06)
    }

    @ViewBuilder
    private func icon(for day: DayCompletion, isFuture: Bool) -> some View {
        if day.hasStrength {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        } else if day.hasCardio {
            Image(systemName: "figure.walk")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.training)
        }
    }
}
