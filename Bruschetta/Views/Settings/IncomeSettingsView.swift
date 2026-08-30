import SwiftUI
import SwiftData

struct IncomeSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [Income]

    @State private var amountText: String = ""
    @State private var cadence: PayCadence = .biweekly
    @State private var nextPayDate: Date = Date()

    var body: some View {
        Form {
            Section("Income Amount") {
                CurrencyTextField(placeholder: "Income per pay period", text: $amountText)
            }

            Section("Pay Cadence") {
                Picker("Cadence", selection: $cadence) {
                    ForEach(PayCadence.allCases, id: \.self) { cadence in
                        Text(cadence.displayName).tag(cadence)
                    }
                }
            }

            Section("Next Pay Date") {
                DatePicker("Next pay date", selection: $nextPayDate, displayedComponents: .date)
            }
        }
        .navigationTitle("Income")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(parsedAmount(amountText) == nil)
            }
        }
        .onAppear { load() }
    }

    private func load() {
        guard let income = incomes.first else { return }
        amountText = String(format: "%.2f", income.amount)
        cadence = income.cadence
        nextPayDate = income.nextPayDate
    }

    private func parsedAmount(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let amount = parsedAmount(amountText) else { return }
        if let income = incomes.first {
            income.amount = amount
            income.cadence = cadence
            income.nextPayDate = nextPayDate
        } else {
            let income = Income(amount: amount, payCadence: cadence, nextPayDate: nextPayDate)
            modelContext.insert(income)
        }
        try? modelContext.save()
    }
}
