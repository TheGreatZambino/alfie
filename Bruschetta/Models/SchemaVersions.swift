import SwiftData

enum AppSchema {
    static var models: [any PersistentModel.Type] {
        [
            Income.self, Category.self, Bill.self, Transaction.self, SavingsAccount.self, RetirementAccount.self,
            Exercise.self, WorkoutTemplate.self, TemplateExerciseEntry.self, TemplateSetEntry.self,
            WorkoutSession.self, LoggedSet.self, WorkoutGoals.self,
            FoodItem.self, NutritionEntry.self, NutritionGoals.self, WaterEntry.self,
            ShoppingItem.self, ShoppingListTemplate.self, ShoppingTemplateItem.self,
            Recipe.self
        ]
    }
}
