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

    static let all: [RetirementSource] = [targetIncome, accountTaxTreatment]
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
