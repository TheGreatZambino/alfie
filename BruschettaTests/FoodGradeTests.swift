import Testing
import Foundation
@testable import Bruschetta

@MainActor
struct FoodGradeTests {
    private func estimate(calories: Double = 0, sugar: Double = 0, fat: Double = 0, sodium: Double = 0,
                          fiber: Double = 0, protein: Double = 0) -> FoodGrade {
        .estimate(caloriesPer100g: calories, sugarPer100g: sugar, fatPer100g: fat,
                  sodiumMgPer100g: sodium, fiberPer100g: fiber, proteinPer100g: protein)
    }

    // MARK: - Parsing

    @Test
    func nutriScoreLetterParsesCaseInsensitively() {
        #expect(FoodGrade(nutriScore: "a") == .a)
        #expect(FoodGrade(nutriScore: "E") == .e)
        #expect(FoodGrade(nutriScore: "unknown") == nil)
        #expect(FoodGrade(nutriScore: nil) == nil)
    }

    @Test
    func gradesOrderFromEToA() {
        #expect(FoodGrade.a > .b)
        #expect(FoodGrade.d < .c)
        #expect(FoodGrade.allCases.min() == .e)
    }

    // MARK: - Estimation

    @Test
    func leanProteinEstimatesA() {
        #expect(estimate(calories: 165, fat: 3.6, sodium: 74, protein: 31) == .a)
    }

    @Test
    func skinOnChickenThighGetsLeanProteinBonus() {
        // Base score 3 (C) without the bonus.
        #expect(estimate(calories: 211, fat: 15, sodium: 80, protein: 17) == .b)
    }

    @Test
    func leanProteinBonusDoesNotLiftDOrEFoods() {
        // Bacon-like: base D, high protein, no sugar.
        #expect(estimate(calories: 540, fat: 42, sodium: 1700, protein: 37) == .e)
        #expect(estimate(calories: 300, fat: 25, sodium: 1100, protein: 20) == .d)
    }

    @Test
    func leanProteinBonusRequiresLowSugar() {
        #expect(estimate(calories: 400, sugar: 25, fat: 15, sodium: 150, fiber: 5, protein: 15) == .c)
    }

    @Test
    func wholeFruitEstimatesB() {
        #expect(estimate(calories: 52, sugar: 10, fat: 0.2, sodium: 1, fiber: 2.4, protein: 0.3) == .b)
    }

    @Test
    func granolaBarEstimatesC() {
        #expect(estimate(calories: 400, sugar: 25, fat: 15, sodium: 150, fiber: 5, protein: 7) == .c)
    }

    @Test
    func candyEstimatesD() {
        #expect(estimate(calories: 400, sugar: 60, fat: 5, sodium: 50) == .d)
    }

    @Test
    func saltyFriedSnackEstimatesE() {
        #expect(estimate(calories: 550, sugar: 5, fat: 35, sodium: 1000, fiber: 4, protein: 6) == .e)
    }

    // MARK: - Averaging

    @Test
    func averageOfNothingIsNil() {
        #expect(FoodGrade.average(of: []) == nil)
        let noEntries: [NutritionEntry] = []
        #expect(noEntries.averageGrade == nil)
    }

    @Test
    func averageWeightsByCalories() {
        // 100 cal of A against 300 cal of E: (5*100 + 1*300) / 400 = 2 -> D
        #expect(FoodGrade.average(of: [(.a, 100), (.e, 300)]) == .d)
    }

    @Test
    func averageFallsBackToEvenWeightWhenNoCalories() {
        #expect(FoodGrade.average(of: [(.a, 0), (.c, 0)]) == .b)
    }

    @Test
    func averageRoundsHalfUp() {
        // (4 + 5) / 2 = 4.5 -> A
        #expect(FoodGrade.average(of: [(.b, 1), (.a, 1)]) == .a)
    }

    @Test
    func singleGradeAveragesToItself() {
        for grade in FoodGrade.allCases {
            #expect(FoodGrade.average(of: [(grade, 250)]) == grade)
        }
    }

    // MARK: - FoodItem / entries

    @Test
    func officialNutriScoreOverridesEstimate() {
        let item = FoodItem(name: "Chips", source: .openFoodFacts, servingSizeGrams: 100,
                            calories: 550, fatGrams: 35, sodiumMilligrams: 1000)
        #expect(item.grade == .e)
        #expect(item.isGradeEstimated)
        item.nutriScoreRaw = "b"
        #expect(item.grade == .b)
        #expect(!item.isGradeEstimated)
    }

    @Test
    func estimateScalesServingToPer100g() {
        // Same food expressed per 100 g and per 50 g serving should grade identically.
        let per100 = FoodItem(name: "Bar", source: .custom, servingSizeGrams: 100,
                              calories: 400, proteinGrams: 7, fatGrams: 15, sugarGrams: 25, fiberGrams: 5, sodiumMilligrams: 150)
        let per50 = FoodItem(name: "Bar", source: .custom, servingSizeGrams: 50,
                             calories: 200, proteinGrams: 3.5, fatGrams: 7.5, sugarGrams: 12.5, fiberGrams: 2.5, sodiumMilligrams: 75)
        #expect(per100.grade == .c)
        #expect(per50.grade == per100.grade)
    }

    @Test
    func foodWithoutNutrientDataIsUngraded() {
        let blank = FoodItem(name: "Mystery", source: .custom)
        #expect(blank.grade == nil)
    }

    @Test
    func foodWithTinyServingWeightIsUngraded() {
        let recipe = FoodItem(name: "Stew", source: .custom, servingSizeGrams: 1, servingDescription: "1 serving", calories: 500, proteinGrams: 30)
        #expect(recipe.grade == nil)
    }

    @Test
    func entriesAverageSkipsUngradedFoods() {
        let chicken = FoodItem(name: "Chicken", source: .custom, servingSizeGrams: 100, calories: 165, proteinGrams: 31, fatGrams: 3.6, sodiumMilligrams: 74)
        let blank = FoodItem(name: "Mystery", source: .custom)
        let entries = [
            NutritionEntry(mealType: .lunch, quantity: 1, foodItem: chicken),
            NutritionEntry(mealType: .lunch, quantity: 1, foodItem: blank)
        ]
        #expect(entries.averageGrade == .a)
    }

    @Test
    func entryQuantityWeightsTheMealAverage() {
        let chicken = FoodItem(name: "Chicken", source: .custom, servingSizeGrams: 100, calories: 165, proteinGrams: 31, fatGrams: 3.6, sodiumMilligrams: 74)
        let chips = FoodItem(name: "Chips", source: .custom, servingSizeGrams: 100, calories: 550, proteinGrams: 6, fatGrams: 35, sodiumMilligrams: 1000)
        // 165 cal of A vs 1650 cal of E: (5*165 + 1*1650) / 1815 ~ 1.45 -> E
        let entries = [
            NutritionEntry(mealType: .dinner, quantity: 1, foodItem: chicken),
            NutritionEntry(mealType: .dinner, quantity: 3, foodItem: chips)
        ]
        #expect(entries.averageGrade == .e)
    }

    // MARK: - Open Food Facts decoding

    @Test
    func offProductCarriesNutriScoreGrade() throws {
        let json = """
        {"code": "0002", "product_name": "Cereal", "nutriscore_grade": "c",
         "nutriments": {"energy-kcal_100g": 380}}
        """
        let product = try JSONDecoder().decode(OFFProduct.self, from: Data(json.utf8))
        let result = try #require(product.asFoodResult(barcode: "0002"))
        #expect(result.nutriScore == "c")
        #expect(result.grade == .c)
        #expect(!result.isGradeEstimated)
    }

    @Test
    func offProductWithoutNutriScoreEstimates() throws {
        let json = """
        {"code": "0003", "product_name": "Chicken", "nutriments":
         {"energy-kcal_100g": 165, "proteins_100g": 31, "fat_100g": 3.6, "sodium_100g": 0.074}}
        """
        let product = try JSONDecoder().decode(OFFProduct.self, from: Data(json.utf8))
        let result = try #require(product.asFoodResult(barcode: "0003"))
        #expect(result.nutriScore == nil)
        #expect(result.isGradeEstimated)
        #expect(result.grade == .a)
    }
}
