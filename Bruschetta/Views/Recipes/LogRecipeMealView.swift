import SwiftUI
import SwiftData

/// Logs one serving of a recipe to a meal for today. Recipes carry no nutrition data, so the
/// per-serving macros are entered here and remembered on a "Recipe" `FoodItem` for next time.
struct LogRecipeMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let onLogged: (MealType) -> Void

    @State private var meal: MealType
    @State private var servingsText = "1"
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""

    private static let brand = "Recipe"

    init(recipe: Recipe, onLogged: @escaping (MealType) -> Void) {
        self.recipe = recipe
        self.onLogged = onLogged
        let hour = Calendar.current.component(.hour, from: Date())
        _meal = State(initialValue: hour < 11 ? .breakfast : hour < 15 ? .lunch : hour < 21 ? .dinner : .snack)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Add to today's") {
                    Picker("Meal", selection: $meal) {
                        ForEach(MealType.allCases) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    HStack {
                        Text("Servings eaten")
                        Spacer()
                        TextField("1", text: $servingsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section {
                    numberField("Calories", text: $caloriesText)
                    numberField("Protein (g)", text: $proteinText)
                    numberField("Carbs (g)", text: $carbsText)
                    numberField("Fat (g)", text: $fatText)
                } header: {
                    Text("Nutrition per serving")
                } footer: {
                    Text("Recipes don't include nutrition info, so enter it once and it will be remembered next time you make \(recipe.name).")
                }
            }
            .alfieListStyle()
            .navigationTitle("I Made It")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(quantity <= 0)
                }
            }
            .onAppear(perform: prefill)
        }
        .presentationDetents([.large])
    }

    private var quantity: Double { Double(servingsText) ?? 0 }

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

    private func existingFood() -> FoodItem? {
        let name = recipe.name, brand = Self.brand
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.name == name && $0.brand == brand })
        return try? modelContext.fetch(descriptor).first
    }

    private func prefill() {
        guard let food = existingFood() else { return }
        caloriesText = Self.format(food.calories)
        proteinText = Self.format(food.proteinGrams)
        carbsText = Self.format(food.carbsGrams)
        fatText = Self.format(food.fatGrams)
    }

    private static func format(_ value: Double) -> String {
        value == 0 ? "" : (value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value))
    }

    private func save() {
        let food: FoodItem
        if let existing = existingFood() {
            food = existing
        } else {
            food = FoodItem(name: recipe.name, brand: Self.brand, source: .custom,
                            servingSizeGrams: 1, servingDescription: "1 serving", isUserCreated: true)
            modelContext.insert(food)
        }
        food.calories = Double(caloriesText) ?? 0
        food.proteinGrams = Double(proteinText) ?? 0
        food.carbsGrams = Double(carbsText) ?? 0
        food.fatGrams = Double(fatText) ?? 0
        modelContext.insert(NutritionEntry(date: Date(), mealType: meal, quantity: quantity, foodItem: food))
        try? modelContext.save()
        onLogged(meal)
        dismiss()
    }
}
