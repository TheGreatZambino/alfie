import SwiftUI
import SwiftData

/// Edits a `FoodItem` in place. Every `NutritionEntry` referencing this item computes its
/// macros live from the item's stored values, so a correction here fixes both past and
/// future logs of the same food — no need to re-correct it each time it's eaten again.
struct EditFoodItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let foodItem: FoodItem

    @State private var name: String
    @State private var servingDescription: String
    @State private var servingSizeGramsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var sugarText: String
    @State private var fiberText: String
    @State private var sodiumText: String
    @State private var showMoreNutrients = false

    init(foodItem: FoodItem) {
        self.foodItem = foodItem
        _name = State(initialValue: foodItem.name)
        _servingDescription = State(initialValue: foodItem.servingDescription)
        _servingSizeGramsText = State(initialValue: Self.format(foodItem.servingSizeGrams))
        _caloriesText = State(initialValue: Self.format(foodItem.calories))
        _proteinText = State(initialValue: Self.format(foodItem.proteinGrams))
        _carbsText = State(initialValue: Self.format(foodItem.carbsGrams))
        _fatText = State(initialValue: Self.format(foodItem.fatGrams))
        _sugarText = State(initialValue: Self.format(foodItem.sugarGrams))
        _fiberText = State(initialValue: Self.format(foodItem.fiberGrams))
        _sodiumText = State(initialValue: Self.format(foodItem.sodiumMilligrams))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Serving")
                        Spacer()
                        TextField("e.g. 100 g", text: $servingDescription)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Serving size (g)")
                        Spacer()
                        TextField("100", text: $servingSizeGramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Nutrition per Serving") {
                    numberField("Calories", text: $caloriesText)
                    numberField("Protein (g)", text: $proteinText)
                    numberField("Carbs (g)", text: $carbsText)
                    numberField("Fat (g)", text: $fatText)
                }

                DisclosureGroup("More", isExpanded: $showMoreNutrients) {
                    numberField("Sugar (g)", text: $sugarText)
                    numberField("Fiber (g)", text: $fiberText)
                    numberField("Sodium (mg)", text: $sodiumText)
                }

                Section {
                    Text("This updates \"\(foodItem.name)\" everywhere it's logged, including past entries, so you won't need to fix it again next time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private func save() {
        foodItem.name = name.trimmingCharacters(in: .whitespaces)
        foodItem.servingDescription = servingDescription
        let servingSizeGrams = Double(servingSizeGramsText) ?? foodItem.servingSizeGrams
        foodItem.servingSizeGrams = servingSizeGrams > 0 ? servingSizeGrams : 100
        foodItem.calories = Double(caloriesText) ?? 0
        foodItem.proteinGrams = Double(proteinText) ?? 0
        foodItem.carbsGrams = Double(carbsText) ?? 0
        foodItem.fatGrams = Double(fatText) ?? 0
        foodItem.sugarGrams = Double(sugarText) ?? 0
        foodItem.fiberGrams = Double(fiberText) ?? 0
        foodItem.sodiumMilligrams = Double(sodiumText) ?? 0
        try? modelContext.save()
        dismiss()
    }
}
