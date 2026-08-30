import SwiftUI
import Charts

struct SpendingByCategoryCard: View {
    let items: [(category: Category, amount: Double)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spending by Category")
                .font(.headline)

            if items.isEmpty {
                Text("No spending recorded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(items, id: \.category.name) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.category.name)
                        )
                        .foregroundStyle(Color(hex: item.category.colorHex))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text(item.amount, format: .currency(code: "USD"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(items.count) * 36 + 20)
            }
        }
        .cardStyle()
    }
}
