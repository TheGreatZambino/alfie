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
                slider(title: "Withdrawal rate", value: $plan.withdrawalRatePercent, range: 2.5...6, step: 0.25, format: "%.2f%%")
            } header: {
                Text("Spending in retirement")
            } footer: {
                Text("Savings needed = yearly income goal ÷ withdrawal rate. A lower rate is more cautious and needs more savings.")
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
