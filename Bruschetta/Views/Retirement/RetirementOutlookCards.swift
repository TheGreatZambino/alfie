import SwiftUI
import Charts

/// "Are you on track?" card: projected savings against the savings needed for the income goal.
struct OnTrackCard: View {
    let outlook: RetirementOutlook
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

            if let status = outlook.status, let progress = outlook.progress {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().stroke(Color.retirementTint, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: min(progress, 1))
                            .stroke(color(for: status), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                    }
                    .frame(width: 76, height: 76)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title(for: status))
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(color(for: status))
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkSecondary)
                    }
                }

                VStack(spacing: 8) {
                    row("Projected at retirement", outlook.expected)
                    row("Savings needed", outlook.requiredNestEgg)
                    if outlook.gap > 0 { row("Gap", outlook.gap, emphasize: true) }
                }

                if let extra = outlook.extraMonthlyNeeded {
                    Label("Saving about \(extra.formatted(.currency(code: "USD").precision(.fractionLength(0)))) more per month would close the gap.", systemImage: "arrow.up.right.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.ink)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.retirementTint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                Text("Set an income goal to see your progress.")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }

            Text("Preliminary: this doesn't yet count Social Security or taxes, so it asks for more savings than your final estimate will. Results are in today's dollars.")
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
        String(format: "%.1f%% / %.1f%% / %.2g%%", plan.stockRealReturnPercent, plan.bondRealReturnPercent, plan.withdrawalRatePercent)
    }

    private var subtitle: String {
        let years = outlook.totalMonths / 12
        let when = years == 0 ? "at retirement" : "in \(years) year\(years == 1 ? "" : "s")"
        return "Projected savings \(when), compared with what your income goal needs."
    }

    private func title(for status: OnTrackStatus) -> String {
        switch status {
        case .onTrack: return "On track"
        case .close: return "Close"
        case .behind: return "Behind"
        }
    }

    private func color(for status: OnTrackStatus) -> Color {
        switch status {
        case .onTrack: return .money
        case .close: return .food
        case .behind: return .training
        }
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
    let outlook: RetirementOutlook

    private struct Band: Identifiable {
        let years: Double
        let low: Double
        let high: Double
        var id: Double { years }
    }

    private var bands: [Band] {
        zip(outlook.lowSeries, outlook.highSeries).map { Band(years: $0.years, low: $0.balance, high: $1.balance) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROJECTED SAVINGS").sectionLabelStyle()
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
                    if outlook.requiredNestEgg > 0 {
                        RuleMark(y: .value("Needed", outlook.requiredNestEgg))
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
