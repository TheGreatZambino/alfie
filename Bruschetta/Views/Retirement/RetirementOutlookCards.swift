import SwiftUI
import Charts

private let currencyWhole = FloatingPointFormatStyle<Double>.Currency(code: "USD").precision(.fractionLength(0))

/// "Are you on track?" card: whether the projected savings can fund the income goal through
/// the plan-to age.
struct OnTrackCard: View {
    let report: RetirementReport
    let plan: RetirementPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ARE YOU ON TRACK?").sectionLabelStyle()
                Spacer()
                NavigationLink { RetirementSourcesView() } label: {
                    Image(systemName: "info.circle").foregroundStyle(Color.inkTertiary)
                }
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.retirementTint, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: report.expected.fundedFraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((report.expected.fundedFraction * 100).rounded()))%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                }
                .frame(width: 76, height: 76)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(color)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            VStack(spacing: 8) {
                row("Projected at retirement", report.accumulation.expected)
                if let needed = report.neededAtRetirement {
                    row("Savings needed", needed)
                    if needed > report.accumulation.expected {
                        row("Gap", needed - report.accumulation.expected, emphasize: true)
                    }
                }
            }

            scenarioLine

            if let extra = report.extraMonthlyNeeded, extra > 0.5 {
                Label("Saving about \(extra.formatted(currencyWhole)) more per month would close the gap.", systemImage: "arrow.up.right.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.retirementTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Text("Estimate in today's dollars. Your goal is treated as spending money after taxes. Includes Social Security and federal tax with simplifications; see Sources.")
                .font(.rowDetail)
                .foregroundStyle(Color.inkTertiary)

            NavigationLink {
                RetirementAssumptionsView(plan: plan)
            } label: {
                HStack {
                    Text("Assumptions")
                    Spacer()
                    Text(summary)
                        .foregroundStyle(Color.inkTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkQuaternary)
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.retirement)
            }
        }
        .cardStyle()
    }

    private var summary: String {
        String(format: "%.1f%% / %.1f%% · to %d", plan.stockRealReturnPercent, plan.bondRealReturnPercent, plan.planToAge)
    }

    private var title: String {
        switch report.status {
        case .onTrack: return "On track"
        case .close: return "Close"
        case .behind: return "Behind"
        }
    }

    private var color: Color {
        switch report.status {
        case .onTrack: return .money
        case .close: return .food
        case .behind: return .training
        }
    }

    private var subtitle: String {
        if let age = report.expected.firstShortfallAge {
            return "At this pace your money runs short around age \(age), before the plan-to age of \(report.planToAge)."
        }
        return "Your income goal is funded through age \(report.planToAge)."
    }

    private var scenarioLine: some View {
        HStack(spacing: 10) {
            scenario("Low", report.low)
            scenario("Expected", report.expected)
            scenario("High", report.high)
        }
    }

    private func scenario(_ label: String, _ result: DrawdownResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.rowDetail).foregroundStyle(Color.inkTertiary)
            Text(result.firstShortfallAge.map { "Short at \($0)" } ?? "Funded")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(result.isFullyFunded ? Color.money : Color.training)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.retirementTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ label: String, _ value: Double, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(emphasize ? Color.training : Color.ink)
        }
    }
}

/// Household savings from now until retirement, with a low/high range and the savings needed.
struct ProjectionChartCard: View {
    let report: RetirementReport

    private struct Band: Identifiable {
        let years: Double
        let low: Double
        let high: Double
        var id: Double { years }
    }

    private var outlook: RetirementOutlook { report.accumulation }

    private var bands: [Band] {
        zip(outlook.lowSeries, outlook.highSeries).map { Band(years: $0.years, low: $0.balance, high: $1.balance) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SAVINGS UNTIL RETIREMENT").sectionLabelStyle()
                Spacer()
                Text("Today's dollars")
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            }

            if outlook.totalMonths > 0 {
                Chart {
                    ForEach(bands) { band in
                        AreaMark(
                            x: .value("Years", band.years),
                            yStart: .value("Low", band.low),
                            yEnd: .value("High", band.high)
                        )
                        .foregroundStyle(Color.retirement.opacity(0.18))
                    }
                    ForEach(outlook.expectedSeries) { point in
                        LineMark(x: .value("Years", point.years), y: .value("Savings", point.balance))
                            .foregroundStyle(Color.retirement)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    if let needed = report.neededAtRetirement, needed > 0 {
                        RuleMark(y: .value("Needed", needed))
                            .foregroundStyle(Color.training)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Needed")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.training)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel {
                            if let years = value.as(Double.self) { Text("\(Int(years))y") }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: "USD").notation(.compactName).precision(.fractionLength(0...1)))
                            }
                        }
                    }
                }
                .frame(height: 200)

                HStack(spacing: 14) {
                    legend(color: .retirement, text: "Expected")
                    legend(color: .retirement.opacity(0.3), text: "Low–high range")
                }
                Text("The range moves every return down or up by 2 percentage points. It's a sensitivity check, not a forecast.")
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            } else {
                Text("You've reached your retirement age, so there's no time left to project.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .cardStyle()
    }

    private func legend(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 14, height: 6)
            Text(text).font(.rowDetail).foregroundStyle(Color.inkSecondary)
        }
    }
}

/// Where retirement income comes from each year, and what taxes take out.
struct RetirementIncomeCard: View {
    let report: RetirementReport

    private struct Segment: Identifiable {
        let age: Int
        let source: String
        let amount: Double
        var id: String { "\(age)-\(source)" }
    }

    private static let sources = ["Social Security", "Taxable accounts", "Pre-tax accounts", "Roth accounts", "Taxes"]
    private static let colors: [Color] = [.money, .food, .retirement, Color(hex: "#7C5CA8"), .training]

    private var segments: [Segment] {
        report.expected.years.flatMap { year in
            [
                Segment(age: year.age, source: "Social Security", amount: year.socialSecurity),
                Segment(age: year.age, source: "Taxable accounts", amount: year.taxableWithdrawal),
                Segment(age: year.age, source: "Pre-tax accounts", amount: year.preTaxWithdrawal),
                Segment(age: year.age, source: "Roth accounts", amount: year.rothWithdrawal),
                Segment(age: year.age, source: "Taxes", amount: -year.totalTaxes)
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RETIREMENT INCOME").sectionLabelStyle()
                Spacer()
                NavigationLink { RetirementSourcesView() } label: {
                    Image(systemName: "info.circle").foregroundStyle(Color.inkTertiary)
                }
            }

            if let first = report.firstYear {
                VStack(spacing: 8) {
                    line("Social Security", first.socialSecurity)
                    line("From your accounts", first.taxableWithdrawal + first.preTaxWithdrawal + first.rothWithdrawal)
                    line("Taxes", -first.totalTaxes)
                    Divider().overlay(Color.hairline)
                    line("Spendable (first year)", first.netIncome, bold: true)
                }

                Chart {
                    ForEach(segments) { segment in
                        BarMark(x: .value("Age", segment.age), y: .value("Amount", segment.amount))
                            .foregroundStyle(by: .value("Source", segment.source))
                    }
                    RuleMark(y: .value("Goal", report.targetSpending))
                        .foregroundStyle(Color.ink.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                }
                .chartForegroundStyleScale(domain: Self.sources, range: Self.colors)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: "USD").notation(.compactName).precision(.fractionLength(0...1)))
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                .frame(height: 230)

                Text("Dashed line is your spending goal. Bars above it pay the taxes shown below the axis.")
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
                if !report.expected.isFullyFunded {
                    Text("Savings run out partway, so the chart ends where the goal can no longer be met.")
                        .font(.rowDetail)
                        .foregroundStyle(Color.training)
                }
            }
        }
        .cardStyle()
    }

    private func line(_ label: String, _ value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: bold ? .semibold : .regular))
                .foregroundStyle(Color.inkSecondary)
            Spacer()
            Text(value, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.ink)
        }
    }
}
