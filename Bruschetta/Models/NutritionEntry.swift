import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .snack: return "leaf"
        }
    }
}

@Model
final class NutritionEntry {
    var date: Date = Date()
    var mealTypeRaw: String = MealType.snack.rawValue
    var quantity: Double = 1
    var foodItem: FoodItem?

    init(date: Date = Date(), mealType: MealType, quantity: Double = 1, foodItem: FoodItem?) {
        self.date = date
        self.mealTypeRaw = mealType.rawValue
        self.quantity = quantity
        self.foodItem = foodItem
    }

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var calories: Double { (foodItem?.calories ?? 0) * quantity }
    var proteinGrams: Double { (foodItem?.proteinGrams ?? 0) * quantity }
    var carbsGrams: Double { (foodItem?.carbsGrams ?? 0) * quantity }
    var fatGrams: Double { (foodItem?.fatGrams ?? 0) * quantity }
}

@Model
final class NutritionGoals {
    var calorieGoal: Double = 2000
    var proteinGoalGrams: Double = 150
    var carbsGoalGrams: Double = 200
    var fatGoalGrams: Double = 65
    var updatedAt: Date = Date()

    init(calorieGoal: Double = 2000, proteinGoalGrams: Double = 150, carbsGoalGrams: Double = 200, fatGoalGrams: Double = 65) {
        self.calorieGoal = calorieGoal
        self.proteinGoalGrams = proteinGoalGrams
        self.carbsGoalGrams = carbsGoalGrams
        self.fatGoalGrams = fatGoalGrams
    }
}
