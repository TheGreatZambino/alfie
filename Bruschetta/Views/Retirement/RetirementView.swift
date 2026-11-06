import SwiftUI
import SwiftData

/// The Retirement tab. Until the user runs setup it shows a short intro; afterwards it shows
/// their income goal, what they've saved by tax bucket, and a nudge when balances are stale.
struct RetirementView: View {
    @Query private var plans: [RetirementPlan]
    @Query(sort: \PlanPerson.order) private var allPeople: [PlanPerson]
    @Query(sort: \RetirementAccount.name) private var accounts: [RetirementAccount]

    @State private var showSetup = false

    private var plan: RetirementPlan? {
        guard let plan = plans.first, plan.isSetupComplete else { return nil }
        return plan
    }

    private var people: [PlanPerson] {
        Array(allPeople.prefix(plan?.isCouple == true ? 2 : 1))
    }

    private var combinedGross: Double {
        people.reduce(0) { $0 + $1.grossAnnualIncome }
    }

    private var staleCount: Int {
        accounts.filter { $0.freshness != .fresh }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    if let plan, !people.isEmpty {
                        targetCard(plan: plan)
                        if !accounts.isEmpty,
                           let report = RetirementProjector.report(plan: plan, people: allPeople, accounts: accounts) {
                            OnTrackCard(report: report, plan: plan)
                            RetirementIncomeCard(report: report)
                            ProjectionChartCard(report: report)
                        }
                        if !accounts.isEmpty, staleCount > 0 { staleBanner }
                        savedCard
                        projectionNote
                    } else {
                        introCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 90)
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSetup) { RetirementSetupView() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RETIREMENT")
                    .eyebrowStyle(color: .retirement)
                Text(headline)
                    .font(.screenHeadline)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            if plan != nil {
                HStack(spacing: 10) {
                    NavigationLink { RetirementSourcesView() } label: { circleButton("info.circle") }
                    Button { showSetup = true } label: { circleButton("slider.horizontal.3") }
                }
            }
        }
        .frame(minHeight: 84)
        .padding(.top, 8)
    }

    private var headline: String {
        guard plan != nil, let soonest = people.map(\.yearsToRetirement).min() else { return "Plan your future" }
        switch soonest {
        case 0: return "Retirement age reached"
        case 1: return "1 year to go"
        default: return "\(soonest) years to go"
        }
    }

    private func circleButton(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.ink)
            .frame(width: 40, height: 40)
            .background(Color.card, in: Circle())
            .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
    }

    // MARK: - Intro

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            IconBadge(systemName: "chart.line.uptrend.xyaxis", color: .retirement, size: 44, shape: .roundedSquare(radius: 14))
            Text("See how close you are to retirement")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.ink)
            Text("Set your retirement goal, add your 401(k), IRA, Roth and brokerage accounts, and track your progress. Works for one person or a couple.")
                .font(.system(size: 15))
                .foregroundStyle(Color.inkSecondary)
            Text("Setup asks for your gross (before-tax) income, which is used only for this tab.")
                .font(.rowDetail)
                .foregroundStyle(Color.inkTertiary)
            Button { showSetup = true } label: {
                Text("Set up retirement planning")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.retirementFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .cardStyle()
    }

    // MARK: - Target

    private func targetCard(plan: RetirementPlan) -> some View {
        let target = plan.targetAnnualIncome(combinedGross: combinedGross)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("RETIREMENT INCOME GOAL")
                    .eyebrowStyle(color: .white.opacity(0.75))
                Spacer()
                NavigationLink { RetirementSourcesView() } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Text(target, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.heroNumeralScreen)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("per year, in today's dollars")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
            Text(targetDescription(plan: plan, target: target))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            Button { showSetup = true } label: {
                Text("Change goal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .padding(.top, 6)
        }
        .heroCardStyle(pillar: .retirementFill)
    }

    private func targetDescription(plan: RetirementPlan, target: Double) -> String {
        let gross = combinedGross.formatted(.currency(code: "USD").precision(.fractionLength(0)))
        switch plan.targetMode {
        case .percentOfGross:
            let label = plan.isUsingDefaultTarget ? "Default: " : ""
            return "\(label)\(Int(plan.targetPercent))% of your \(gross) gross income"
        case .fixedDollars:
            let percent = combinedGross > 0 ? Int((target / combinedGross * 100).rounded()) : 0
            return "Your own figure, about \(percent)% of your \(gross) gross income"
        }
    }

    // MARK: - Saved

    private var savedCard: some View {
        let total = accounts.reduce(0) { $0 + $1.balance }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SAVED SO FAR").sectionLabelStyle()
                Spacer()
                NavigationLink { RetirementAccountsView() } label: {
                    Text("Accounts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.retirement)
                }
            }

            Text(total, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.heroNumeralCard)
                .foregroundStyle(Color.ink)

            if accounts.isEmpty {
                NavigationLink { RetirementAccountsView() } label: {
                    Label("Add your first account", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.retirement)
                }
            } else {
                HStack(spacing: 10) {
                    ForEach(TaxBucket.allCases) { bucket in
                        bucketTile(bucket)
                    }
                }
            }
        }
        .cardStyle()
    }

    private func bucketTile(_ bucket: TaxBucket) -> some View {
        let amount = accounts.filter { $0.bucket == bucket }.reduce(0) { $0 + $1.balance }
        return VStack(alignment: .leading, spacing: 6) {
            Image(systemName: bucket.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.retirement)
            Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(bucket.title)
                .font(.rowDetail)
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.retirementTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var staleBanner: some View {
        NavigationLink { RetirementAccountsView() } label: {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(Color.training)
                Text(staleCount == 1 ? "1 balance needs a check" : "\(staleCount) balances need a check")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("Update")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.retirement)
            }
            .padding(14)
            .background(Color.training.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var projectionNote: some View {
        Text("Figures here are planning estimates, not tax or financial advice.")
            .font(.rowDetail)
            .foregroundStyle(Color.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
