import SwiftUI
import SwiftData

struct SavingsAccountsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var savingsAccounts: [SavingsAccount]

    @State private var editingAccount: SavingsAccount?

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
                Text("Savings is treated as cash — if a pay period ends with non-bill spending below zero, the shortfall is automatically pulled from this balance. Investments is tracked separately and isn't touched by overspending. Set an amount per paycheck to have it counted as committed funds.")
            }
        }
        .navigationTitle("Savings")
        .sheet(item: $editingAccount) { account in
            SavingsAccountEditView(account: account)
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
