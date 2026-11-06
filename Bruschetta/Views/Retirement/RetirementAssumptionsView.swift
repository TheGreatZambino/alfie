import SwiftUI
import SwiftData

/// Editable projection assumptions. Defaults and their sources are on the Sources screen.
struct RetirementAssumptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: RetirementPlan

    var body: some View {
        Form {
            Section {
                slider(title: "Stock return", value: $plan.stockRealReturnPercent, range: 0...10, step: 0.5, format: "%.1f%%")
                slider(title: "Bond return", value: $plan.bondRealReturnPercent, range: 0...6, step: 0.5, format: "%.1f%%")
            } header: {
                Text("Yearly returns after inflation")
            } footer: {
                Text("Returns are real, meaning after inflation, so results are in today's dollars. Each account uses a blend based on its stock/bond split.")
            }

            Section {
                Stepper(value: $plan.planToAge, in: 80...105) {
                    HStack {
                        Text("Plan to age")
                        Spacer()
                        Text("\(plan.planToAge)").fontWeight(.semibold).foregroundStyle(Color.ink)
                    }
                }
            } header: {
                Text("How long it needs to last")
            } footer: {
                Text("The plan must fund your income goal until the younger of you reaches this age.")
            }

            Section {
                slider(title: "State income tax", value: $plan.stateTaxRatePercent, range: 0...13, step: 0.5, format: "%.1f%%")
            } header: {
                Text("State tax")
            } footer: {
                Text("A flat rate applied to withdrawals from pre-tax and taxable accounts. Most states don't tax Social Security, so it isn't included. Use 0% if your state has no income tax.")
            }

            Section {
                NavigationLink {
                    RetirementSourcesView()
                } label: {
                    Label("Where these numbers come from", systemImage: "info.circle")
                }
                .tint(.retirement)

                if !plan.isUsingDefaultAssumptions {
                    Button("Reset to defaults") {
                        plan.resetAssumptions()
                        try? modelContext.save()
                    }
                    .tint(.retirement)
                }
            }
        }
        .alfieListStyle()
        .navigationTitle("Assumptions")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }

    private func slider(title: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double, format: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.ink)
            }
            Slider(value: value, in: range, step: step)
                .tint(.retirement)
        }
        .padding(.vertical, 2)
    }
}
