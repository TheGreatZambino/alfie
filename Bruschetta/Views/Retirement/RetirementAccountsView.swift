import SwiftUI
import SwiftData

/// All retirement and brokerage accounts, grouped by how they're taxed, with a quick way to
/// refresh every balance at once.
struct RetirementAccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RetirementAccount.name) private var accounts: [RetirementAccount]
    @Query private var plans: [RetirementPlan]
    @Query(sort: \PlanPerson.order) private var people: [PlanPerson]

    @State private var editingAccount: RetirementAccount?
    @State private var showAdd = false
    @State private var showQuickUpdate = false

    private var isCouple: Bool { plans.first?.isCouple ?? false }

    var body: some View {
        List {
            if !accounts.isEmpty {
                Section {
                    Button {
                        showQuickUpdate = true
                    } label: {
                        Label("Update all balances", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.retirement)
                } footer: {
                    Text("Balances are entered by hand. Updating them monthly keeps your projections accurate.")
                }
            }

            ForEach(TaxBucket.allCases) { bucket in
                let bucketAccounts = accounts.filter { $0.bucket == bucket }
                if !bucketAccounts.isEmpty {
                    Section {
                        ForEach(bucketAccounts) { account in
                            Button { editingAccount = account } label: { row(for: account) }
                                .swipeActions(edge: .leading) {
                                    Button("Still correct") {
                                        account.confirmBalance()
                                        try? modelContext.save()
                                    }
                                    .tint(.retirement)
                                }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(bucketAccounts[index]) }
                            try? modelContext.save()
                        }
                    } header: {
                        Text("\(bucket.title) · \(total(of: bucketAccounts).formatted(.currency(code: "USD").precision(.fractionLength(0))))")
                    } footer: {
                        Text(bucket.explanation)
                    }
                }
            }

            Section {
                Button { showAdd = true } label: {
                    Label("Add account", systemImage: "plus.circle.fill")
                }
                .tint(.retirement)
            } footer: {
                if accounts.isEmpty {
                    Text("Add your 401(k), IRA, Roth and brokerage accounts to see how close you are to your goal.")
                } else {
                    NavigationLink {
                        RetirementSourcesView()
                    } label: {
                        Label("How accounts are taxed", systemImage: "info.circle")
                            .font(.system(size: 13))
                    }
                    .tint(.retirement)
                }
            }
        }
        .alfieListStyle()
        .navigationTitle("Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingAccount) { account in
            RetirementAccountForm(account: account, isCouple: isCouple, people: people)
        }
        .sheet(isPresented: $showAdd) {
            RetirementAccountForm(account: nil, isCouple: isCouple, people: people)
        }
        .sheet(isPresented: $showQuickUpdate) {
            QuickUpdateBalancesView(accounts: accounts)
        }
    }

    private func total(of accounts: [RetirementAccount]) -> Double {
        accounts.reduce(0) { $0 + $1.balance }
    }

    private func row(for account: RetirementAccount) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                HStack(spacing: 6) {
                    Text(subtitle(for: account))
                        .font(.rowDetail)
                        .foregroundStyle(Color.inkTertiary)
                    FreshnessBadge(account: account)
                }
            }
            Spacer()
            Text(account.balance, format: .currency(code: "USD"))
                .font(.rowTitle)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    private func subtitle(for account: RetirementAccount) -> String {
        guard isCouple, let owner = people.first(where: { $0.order == account.ownerOrder }) else {
            return account.type.rawValue
        }
        return "\(account.type.rawValue) · \(owner.displayName(fallbackIndex: owner.order))"
    }
}

/// "Updated 12d ago", tinted amber after 30 days and red after 90.
struct FreshnessBadge: View {
    let account: RetirementAccount

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    private var label: String {
        guard let days = account.daysSinceUpdate else { return "Not confirmed" }
        if days <= 0 { return "Updated today" }
        return "Updated \(days)d ago"
    }

    private var color: Color {
        switch account.freshness {
        case .fresh: return .money
        case .aging: return .food
        case .stale: return .training
        }
    }
}

// MARK: - Add / edit

private struct RetirementAccountForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: RetirementAccount?
    let isCouple: Bool
    let people: [PlanPerson]

    @State private var name = ""
    @State private var type: RetirementAccountType = .k401
    @State private var ownerOrder = 0
    @State private var balanceText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(RetirementAccountType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if isCouple {
                        Picker("Owner", selection: $ownerOrder) {
                            ForEach(people.prefix(2)) { person in
                                Text(person.displayName(fallbackIndex: person.order)).tag(person.order)
                            }
                        }
                    }
                } footer: {
                    Text("\(type.rawValue) is taxed as \(type.bucket.title.lowercased()). \(type.bucket.explanation)")
                }

                Section {
                    CurrencyTextField(placeholder: "Balance", text: $balanceText)
                } footer: {
                    Text("Set this to your actual current balance.")
                }
            }
            .alfieListStyle()
            .navigationTitle(account == nil ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(balanceText) == nil)
                }
            }
            .onAppear {
                guard let account else { return }
                name = account.name
                type = account.type
                ownerOrder = account.ownerOrder
                balanceText = String(format: "%.2f", account.balance)
            }
            .onChange(of: type) { _, newType in
                if account == nil, name.isEmpty || RetirementAccountType.allCases.contains(where: { $0.rawValue == name }) {
                    name = newType.rawValue
                }
            }
        }
    }

    private func save() {
        guard let balance = Double(balanceText) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let account {
            account.name = trimmed
            account.type = type
            account.ownerOrder = ownerOrder
            if account.balance != balance || account.balanceUpdatedAt == nil {
                account.updateBalance(balance)
            } else {
                account.confirmBalance()
            }
        } else {
            modelContext.insert(RetirementAccount(name: trimmed, type: type, balance: balance, ownerOrder: ownerOrder))
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Quick update

/// One screen to review every balance. Saving confirms all of them as current, whether or not
/// the number changed.
struct QuickUpdateBalancesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let accounts: [RetirementAccount]

    @State private var texts: [PersistentIdentifier: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(accounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(account.name).font(.rowTitle)
                                FreshnessBadge(account: account)
                            }
                            Spacer()
                            CurrencyTextField(
                                placeholder: "0",
                                text: Binding(
                                    get: { texts[account.persistentModelID] ?? "" },
                                    set: { texts[account.persistentModelID] = $0 }
                                )
                            )
                            .frame(maxWidth: 140)
                        }
                    }
                } footer: {
                    Text("Check each balance against your latest statement. Saving marks all of them as up to date.")
                }
            }
            .alfieListStyle()
            .navigationTitle("Update balances")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(accounts.contains { Double(texts[$0.persistentModelID] ?? "") == nil })
                }
            }
            .onAppear {
                for account in accounts where texts[account.persistentModelID] == nil {
                    texts[account.persistentModelID] = String(format: "%.2f", account.balance)
                }
            }
        }
    }

    private func save() {
        for account in accounts {
            if let value = Double(texts[account.persistentModelID] ?? "") {
                account.updateBalance(value)
            }
        }
        try? modelContext.save()
        dismiss()
    }
}
