import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var incomes: [Income]
    @Query private var categories: [Category]

    @State private var step: Int = 0
    @State private var amountText: String = ""
    @State private var cadence: PayCadence = .biweekly
    @State private var nextPayDate: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                switch step {
                case 0:
                    stepView(title: "What's your income?", subtitle: "Enter the amount you receive each pay period.") {
                        CurrencyTextField(placeholder: "Income per pay period", text: $amountText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 40)
                    }
                case 1:
                    stepView(title: "How often are you paid?", subtitle: "Choose your pay cadence.") {
                        Picker("Cadence", selection: $cadence) {
                            ForEach(PayCadence.allCases, id: \.self) { cadence in
                                Text(cadence.displayName).tag(cadence)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                default:
                    stepView(title: "When's your next payday?", subtitle: "Pick your next pay date.") {
                        DatePicker("Next pay date", selection: $nextPayDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, 20)
                    }
                }

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                    }
                    Spacer()
                    Button(step < 2 ? "Next" : "Finish") {
                        if step < 2 {
                            step += 1
                        } else {
                            finish()
                        }
                    }
                    .disabled(step == 0 && Double(amountText) == nil)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stepView<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            content()
                .padding(.top, 12)
        }
        .padding(.horizontal)
    }

    private func finish() {
        guard let amount = Double(amountText) else { return }

        if let income = incomes.first {
            income.amount = amount
            income.cadence = cadence
            income.nextPayDate = nextPayDate
        } else {
            let income = Income(amount: amount, payCadence: cadence, nextPayDate: nextPayDate)
            modelContext.insert(income)
        }

        if categories.isEmpty {
            var sortOrder = 0
            for seed in Category.defaultSpendingCategories {
                let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .spending, sortOrder: sortOrder)
                modelContext.insert(category)
                sortOrder += 1
            }
            for seed in Category.defaultBillCategories {
                let category = Category(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, type: .bill, sortOrder: sortOrder)
                modelContext.insert(category)
                sortOrder += 1
            }
        }

        try? modelContext.save()
        dismiss()
    }
}
