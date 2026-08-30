import SwiftUI

struct FoodEntryRowView: View {
    let entry: NutritionEntry
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            }
            Spacer()
            Text("\(Int(entry.calories).formatted())")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Entry", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
        }
    }

    private var subtitle: String {
        let servingDescription = entry.foodItem?.servingDescription ?? "serving"
        let dominantMacro = dominantMacroText
        let base = entry.quantity == 1 ? servingDescription : "\(quantityText) × \(servingDescription)"
        guard let dominantMacro else { return base }
        return "\(base) · \(dominantMacro)"
    }

    private var dominantMacroText: String? {
        let macros = [("protein", entry.proteinGrams), ("carbs", entry.carbsGrams), ("fat", entry.fatGrams)]
        guard let top = macros.max(by: { $0.1 < $1.1 }), top.1 > 0 else { return nil }
        return "\(Int(top.1))g \(top.0)"
    }

    private var quantityText: String {
        entry.quantity.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(entry.quantity))
            : String(format: "%.2g", entry.quantity)
    }
}
