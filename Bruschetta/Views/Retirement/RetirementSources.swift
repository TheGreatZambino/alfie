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
        title: "Retirement income goal (80% of gross)",
        usage: "The default goal is 80% of your combined gross income. This is a common planning rule of thumb (retirees often plan for roughly 70–80% of pre-retirement income), not a rule or a government figure. This app treats the goal as the spending money you want after taxes, which is more demanding than treating it as before-tax income. Override it with a percent or a dollar amount that matches how you expect to spend.",
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

    static let retirementIncome = RetirementSource(
        id: "retirement-income",
        title: "How retirement income is simulated",
        usage: "Starting when the last of you retires, each year the app adds Social Security, takes any required distributions, then withdraws from taxable accounts, then pre-tax accounts, then Roth accounts until your after-tax spending goal is met. Surplus income after taxes is reinvested in the taxable account. \"Savings needed\" is the smallest balance that would fund the goal through your plan-to age. Everything is in today's dollars, using today's tax tables for every year. Simplifications: investment income is taxed only when sold; a couple stays married filing jointly for the whole plan (no survivor modeling); Social Security spousal and survivor benefits, the senior deduction added in 2025, the 3.8% net investment income tax, Medicare premiums and state-specific rules are not included; the 10% early-withdrawal tax applies before age 59 with no exceptions.",
        links: []
    )

    static let socialSecurity = RetirementSource(
        id: "social-security",
        title: "Social Security benefits",
        usage: "If you enter your statement's benefit at full retirement age, that is used directly. Otherwise a rough estimate applies the 2026 benefit formula (90% of the first $1,286 of average monthly earnings, 32% up to $7,749, and 15% above) to your gross income, capped at the $184,500 taxable maximum, as if you earned it for 35 years. Full retirement age is 67 for people born in 1960 or later. Claiming early reduces the benefit by 5/9 of 1% per month for the first 36 months and 5/12 of 1% for each month beyond that. Waiting past full retirement age adds 8% a year until 70. Benefits are assumed to keep pace with inflation.",
        links: [
            .init(label: "SSA: Primary insurance amount formula", url: "https://www.ssa.gov/oact/cola/piaformula.html"),
            .init(label: "SSA: Contribution and benefit base", url: "https://www.ssa.gov/oact/cola/cbb.html"),
            .init(label: "SSA: Early or late retirement", url: "https://www.ssa.gov/oact/quickcalc/early_late.html"),
            .init(label: "SSA: Full retirement age and reductions", url: "https://www.ssa.gov/benefits/retirement/planner/agereduction.html")
        ]
    )

    static let federalTax = RetirementSource(
        id: "federal-tax",
        title: "Federal income tax (2026 tables)",
        usage: "Tax uses the 2026 brackets for single filers or married filing jointly, the 2026 standard deduction ($16,100 single, $32,200 joint) plus the extra amount for each person 65 or older ($2,050 unmarried, $1,650 each if married), and the 2026 long-term capital gains thresholds: 0% up to $49,450 (single) or $98,900 (joint), and 15% up to $545,500 or $613,700. Withdrawals from pre-tax accounts are ordinary income. Only the gain in taxable-account sales is taxed, using your cost basis. Roth withdrawals are tax-free. The tables are refreshed each year.",
        links: [
            .init(label: "IRS Revenue Procedure 2025-32 (2026 adjustments)", url: "https://www.irs.gov/pub/irs-drop/rp-25-32.pdf")
        ]
    )

    static let socialSecurityTax = RetirementSource(
        id: "social-security-tax",
        title: "Taxes on Social Security",
        usage: "The taxable part of Social Security follows IRS Publication 915, Worksheet 1: half your benefits plus your other income is compared with $25,000 (single) or $32,000 (joint). Up to 50% of benefits become taxable above that, and up to 85% above $34,000 (single) or $44,000 (joint). These thresholds are not adjusted for inflation by law, and the app keeps them fixed.",
        links: [
            .init(label: "IRS Publication 915", url: "https://www.irs.gov/publications/p915")
        ]
    )

    static let requiredDistributions = RetirementSource(
        id: "required-distributions",
        title: "Required minimum distributions and early withdrawals",
        usage: "Pre-tax accounts must pay out a required amount each year starting at age 73, or 75 for anyone born in 1960 or later (SECURE 2.0). The law is ambiguous for people born in 1959, so the app uses 73. The amount is the prior balance divided by the IRS Uniform Lifetime Table factor (for example 26.5 at age 73). Pre-tax withdrawals before about age 59½ add a 10% additional tax, and the app doesn't model the exceptions.",
        links: [
            .init(label: "IRS Publication 590-B (Table III, Uniform Lifetime)", url: "https://www.irs.gov/publications/p590b"),
            .init(label: "IRS: Required minimum distributions", url: "https://www.irs.gov/retirement-plans/plan-participant-employee/retirement-topics-required-minimum-distributions-rmds")
        ]
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
        targetIncome, projection, returnAssumptions, retirementIncome, socialSecurity, federalTax,
        socialSecurityTax, requiredDistributions, contributionLimits, accountTaxTreatment
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
