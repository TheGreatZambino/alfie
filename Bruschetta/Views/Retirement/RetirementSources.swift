import SwiftUI

/// One cited basis for something the Retirement tab shows or calculates. Every calculation the
/// tab performs must have an entry here; the "Sources & methodology" screen renders this list
/// and the (i) buttons next to results open it.
struct RetirementSource: Identifiable {
    let id: String
    let title: String
    /// Plain-language description of how the source is used in the app.
    let usage: String
    let links: [Link]

    struct Link: Identifiable {
        var id: String { url }
        let label: String
        let url: String
    }
}

enum RetirementSources {
    static let targetIncome = RetirementSource(
        id: "target-income",
        title: "Target retirement income (80% of gross)",
        usage: "The default target is 80% of your combined gross income. This is a common planning rule of thumb (retirees often plan for roughly 70–80% of pre-retirement income), not a rule or a government figure. It's a starting point: override it with a percent or a dollar amount that matches how you expect to spend.",
        links: []
    )

    static let accountTaxTreatment = RetirementSource(
        id: "account-tax-treatment",
        title: "How each account type is taxed",
        usage: "Accounts are grouped as pre-tax (401(k), 403(b), Traditional IRA, SEP IRA), Roth (Roth 401(k), Roth IRA) and taxable (brokerage), because that determines how withdrawals are taxed. Accounts of type \"Other\" are treated as pre-tax, the conservative assumption.",
        links: [
            .init(label: "IRS Publication 590-A: Contributions to IRAs", url: "https://www.irs.gov/publications/p590a"),
            .init(label: "IRS Publication 590-B: Distributions from IRAs", url: "https://www.irs.gov/publications/p590b"),
            .init(label: "IRS Topic 409: Capital gains and losses", url: "https://www.irs.gov/taxtopics/tc409")
        ]
    )

    static let projection = RetirementSource(
        id: "projection",
        title: "How balances are projected",
        usage: "Each account grows at a blend of your stock and bond return assumptions, compounded monthly, with your monthly contributions (yours plus your employer's) added at the end of each month until its owner retires. After that the balance keeps growing without new contributions. This is the standard compound-interest and future-value-of-an-annuity math. Returns are real (after inflation), so every result is in today's dollars. The low and high lines move every return down or up by 2 percentage points; that range is a sensitivity check chosen for this app, not a forecast.",
        links: []
    )

    static let returnAssumptions = RetirementSource(
        id: "return-assumptions",
        title: "Default return assumptions",
        usage: "Defaults are 5.0% a year for stocks and 1.5% for bonds, after inflation. Long-run historical real returns have been higher for stocks (roughly 5–7% a year, depending on edition and market) and about 1–2% for bonds in the UBS Global Investment Returns Yearbook, which tracks markets since 1900. The stock default is deliberately below history to avoid over-promising. Past returns don't guarantee future returns; change them in Assumptions.",
        links: [
            .init(label: "UBS Global Investment Returns Yearbook", url: "https://www.ubs.com/global/en/investment-bank/insights-and-data/articles/global-investment-returns-yearbook-2026.html")
        ]
    )

    static let withdrawalRate = RetirementSource(
        id: "withdrawal-rate",
        title: "Savings needed for your goal (4% withdrawal rate)",
        usage: "The savings needed is your yearly income goal divided by a withdrawal rate, 4% by default. The 4% figure comes from historical-simulation research: William P. Bengen, \"Determining Withdrawal Rates Using Historical Data,\" Journal of Financial Planning (1994), and Cooley, Hubbard and Walz, \"Retirement Savings: Choosing a Withdrawal Rate That Is Sustainable,\" AAII Journal (1998). It is a rule of thumb for a roughly 30-year retirement, not a guarantee. This early estimate does not yet count Social Security or taxes, so it asks for more savings than the final estimate will.",
        links: []
    )

    static let contributionLimits = RetirementSource(
        id: "contribution-limits",
        title: "Annual contribution limits (2026)",
        usage: "Warnings compare your employee contributions with the IRS 2026 limits: $24,500 for 401(k), 403(b) and similar plans, plus $8,000 from age 50 or $11,250 at ages 60–63; and $7,500 for IRAs, plus $1,100 from age 50. Limits are shared across accounts of the same kind for one person. Employer contributions, SEP IRAs, income limits for Roth and deductible IRA contributions, and other plan types are not checked.",
        links: [
            .init(label: "IRS: 401(k) limit increases to $24,500 for 2026, IRA limit to $7,500", url: "https://www.irs.gov/newsroom/401k-limit-increases-to-24500-for-2026-ira-limit-increases-to-7500"),
            .init(label: "IRS Notice 2025-67: 2026 amounts relating to retirement plans", url: "https://www.irs.gov/pub/irs-drop/n-25-67.pdf")
        ]
    )

    static let all: [RetirementSource] = [
        targetIncome, projection, returnAssumptions, withdrawalRate, contributionLimits, accountTaxTreatment
    ]
}

struct RetirementSourcesView: View {
    var body: some View {
        List {
            Section {
                ForEach(RetirementSources.all) { source in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(source.title)
                            .font(.rowTitle)
                            .foregroundStyle(Color.ink)
                        Text(source.usage)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.inkSecondary)
                        ForEach(source.links) { link in
                            if let url = URL(string: link.url) {
                                Link(destination: url) {
                                    Label(link.label, systemImage: "arrow.up.right.square")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .tint(.retirement)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Retirement figures in this app are estimates for planning, not tax, legal or financial advice. Each calculation added to this tab is listed here with its source.")
            }
        }
        .alfieListStyle()
        .navigationTitle("Sources & methodology")
        .navigationBarTitleDisplayMode(.inline)
    }
}
