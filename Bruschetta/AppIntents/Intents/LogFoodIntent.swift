import AppIntents
import SwiftData

struct LogFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food"
    static var description = IntentDescription("Log a food entry in Alfie Track's nutrition tracker.")

    @Parameter(title: "Food", description: "A food you've logged or created before")
    var food: FoodItemEntity

    @Parameter(title: "Servings", default: 1)
    var quantity: Double

    @Parameter(title: "Meal")
    var mealType: MealType

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$quantity) serving(s) of \(\.$food) as \(\.$mealType)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(AppModelContainer.shared)

        guard let persistentID = PersistentIdentifier.from(appEntityID: food.id),
              let foodItem = context.model(for: persistentID) as? FoodItem else {
            throw $food.needsValueError("That food item couldn't be found.")
        }

        let entry = NutritionEntry(mealType: mealType, quantity: quantity, foodItem: foodItem)
        context.insert(entry)
        try context.save()

        let calories = Int(entry.calories)
        return .result(dialog: "Logged \(quantity.formatted()) serving(s) of \(foodItem.name) (\(calories) cal) as \(mealType.displayName.lowercased()).")
    }
}
