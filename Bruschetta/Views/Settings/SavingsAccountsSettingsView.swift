import SwiftUI
import SwiftData

struct SavingsAccountsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savingsAccounts: [SavingsAccount]
    @Query(sort: \RetirementAccount.name) private var retirementAccounts: [RetirementAccount]

    @State private var editingAccount: SavingsAccount?
    @State private var editingRetirement: RetirementAccount?
    @State private var showAddRetirement = false

    var body: some View {
        List {
            Section {
                ForEach(savingsAccounts) { account in
                    Button {
                        editingAccount = account
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .foregroundStyle(.primary)
                                if account.allocationPerPaycheck > 0 {
                                    Text("\(account.allocationPerPaycheck, format: .currency(code: "USD"))/paycheck")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(account.balance, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Savings is treated as cash — if a pay period ends with non-bill spending below zero, the shortfall is automatically pulled from this balance. Investments (post-tax) is tracked separately and isn't touched by overspending. Set an amount per paycheck to have it counted as committed funds.")
            }

            Section {
                ForEach(retirementAccounts) { account in
                    Button {
                        editingRetirement = account
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .foregroundStyle(.primary)
                                Text(account.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(account.balance, format: .currency(code: "USD"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(retirementAccounts[index]) }
                    try? modelContext.save()
                }

                Button {
                    showAddRetirement = true
                } label: {
                    Label("Add Retirement Account", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Retirement")
            } footer: {
                Text("Retirement accounts like a 401(k) or IRA are tracked separately from savings and investments, and aren't touched by overspending.")
            }
        }
        .alfieListStyle()
        .navigationTitle("Savings")
        .sheet(item: $editingAccount) { account in
            SavingsAccountEditView(account: account)
        }
        .sheet(item: $editingRetirement) { account in
            RetirementAccountEditView(account: account)
        }
        .sheet(isPresented: $showAddRetirement) {
            RetirementAccountEditView(account: nil)
        }
    }
}

private struct SavingsAccountEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: SavingsAccount

    @State private var balanceText: String = ""
    @State private var allocationText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyTextField(placeholder: "Balance", text: $balanceText)
                } footer: {
                    Text("Set this to your actual current \(account.name.lowercased()) balance.")
                }

                Section {
                    CurrencyTextField(placeholder: "Allocate per Paycheck", text: $allocationText)
                } footer: {
                    Text("How much you set aside for \(account.name.lowercased()) each paycheck. This is counted as committed funds on the Finances tab.")
                }
            }
            .alfieListStyle()
            .navigationTitle(account.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(balanceText) == nil)
                }
            }
            .onAppear {
                balanceText = String(format: "%.2f", account.balance)
                allocationText = String(format: "%.2f", account.allocationPerPaycheck)
            }
        }
    }

    private func save() {
        guard let balance = Double(balanceText) else { return }
        account.balance = balance
        account.allocationPerPaycheck = Double(allocationText) ?? 0
        try? modelContext.save()
        dismiss()
    }
}

private struct RetirementAccountEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let account: RetirementAccount?

    @State private var name: String = ""
    @State private var type: RetirementAccountType = .k401
    @State private var balanceText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        ForEach(RetirementAccountType.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                Section {
                    CurrencyTextField(placeholder: "Balance", text: $balanceText)
                } footer: {
                    Text("Set this to your actual current balance.")
                }
            }
            .alfieListStyle()
            .navigationTitle(account == nil ? "New Retirement Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || Double(balanceText) == nil)
                }
            }
            .onAppear {
                guard let account else { return }
                name = account.name
                type = account.type
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
            account.balance = balance
        } else {
            modelContext.insert(RetirementAccount(name: trimmed, type: type, balance: balance))
        }
        try? modelContext.save()
        dismiss()
    }
}
