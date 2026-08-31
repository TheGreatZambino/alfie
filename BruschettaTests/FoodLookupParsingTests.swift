import Testing
import Foundation
@testable import Bruschetta

@MainActor
struct FoodLookupParsingTests {
    /// Scaled nutrient math goes through floating-point division/multiplication, so
    /// comparisons use a tolerance rather than exact equality.
    private func isClose(_ a: Double, _ b: Double, tolerance: Double = 0.0001) -> Bool {
        abs(a - b) < tolerance
    }

    // MARK: - Open Food Facts

    private func decodeOFFProduct(_ json: String) throws -> OFFProduct {
        try JSONDecoder().decode(OFFProduct.self, from: Data(json.utf8))
    }

    @Test
    func offProductScalesPer100gValuesByLabeledServing() throws {
        let json = """
        {
            "code": "0001",
            "product_name": "Protein Bar",
            "brands": "Acme, Other",
            "serving_quantity": 50,
            "nutriments": {
                "energy-kcal_100g": 200,
                "proteins_100g": 20,
                "carbohydrates_100g": 10,
                "fat_100g": 5,
                "sugars_100g": 4,
                "fiber_100g": 2,
                "sodium_100g": 0.1
            }
        }
        """
        let product = try decodeOFFProduct(json)
        let result = try #require(product.asFoodResult(barcode: "0001"))

        #expect(result.brand == "Acme")
        #expect(result.servingSizeGrams == 50)
        #expect(isClose(result.calories, 100)) // 200 * (50/100)
        #expect(isClose(result.proteinGrams, 10))
        #expect(isClose(result.sodiumMilligrams, 50)) // 0.1g/100g scaled to 50g, then *1000 to mg
    }

    @Test
    func offProductPrefersServingValuesOverScaledPer100gValues() throws {
        let json = """
        {
            "product_name": "Cereal",
            "serving_quantity": 40,
            "nutriments": {
                "energy-kcal_100g": 300,
                "energy-kcal_serving": 90
            }
        }
        """
        let product = try decodeOFFProduct(json)
        let result = try #require(product.asFoodResult(barcode: nil))
        #expect(isClose(result.calories, 90))
    }

    @Test
    func offProductFallsBackTo100GramsWhenNoServingInfoAvailable() throws {
        let json = """
        {
            "product_name": "Mystery Snack",
            "nutriments": { "energy-kcal_100g": 250 }
        }
        """
        let product = try decodeOFFProduct(json)
        let result = try #require(product.asFoodResult(barcode: nil))
        #expect(result.servingSizeGrams == 100)
        #expect(isClose(result.calories, 250))
    }

    @Test
    func offProductReturnsNilWithoutNameOrNutriments() throws {
        let withoutName = try decodeOFFProduct("""
        { "nutriments": { "energy-kcal_100g": 100 } }
        """)
        #expect(withoutName.asFoodResult(barcode: nil) == nil)

        let withoutNutriments = try decodeOFFProduct("""
        { "product_name": "Something" }
        """)
        #expect(withoutNutriments.asFoodResult(barcode: nil) == nil)
    }

    @Test
    func parseGramsExtractsGramsFromFreeTextServingSize() {
        #expect(OFFProduct.parseGrams(from: "1 bar (28g)") == 28)
        #expect(OFFProduct.parseGrams(from: "1 bar (28.5 g)") == 28.5)
        #expect(OFFProduct.parseGrams(from: "one serving") == nil)
        #expect(OFFProduct.parseGrams(from: nil) == nil)
    }

    @Test
    func formatGramsDropsDecimalForWholeNumbers() {
        #expect(OFFProduct.formatGrams(100) == "100 g")
        #expect(OFFProduct.formatGrams(28.5) == "28.5 g")
    }

    // MARK: - USDA FoodData Central

    private func decodeUSDAFood(_ json: String) throws -> USDAFood {
        try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8))
    }

    @Test
    func usdaFoodScalesPer100gNutrientsByLabelServing() throws {
        let json = """
        {
            "fdcId": 123,
            "description": "Almonds",
            "gtinUpc": "00012345",
            "servingSize": 28,
            "servingSizeUnit": "g",
            "foodNutrients": [
                { "nutrientName": "Energy", "unitName": "KCAL", "value": 600 },
                { "nutrientName": "Protein", "unitName": "G", "value": 20 }
            ]
        }
        """
        let food = try decodeUSDAFood(json)
        let result = food.asFoodResult()

        #expect(result.servingSizeGrams == 28)
        #expect(isClose(result.calories, 168)) // 600 * 0.28
        #expect(isClose(result.proteinGrams, 5.6))
    }

    @Test
    func usdaFoodDefaultsToHundredGramsWhenServingUnitIsNotGrams() throws {
        let json = """
        {
            "fdcId": 456,
            "description": "Juice",
            "servingSize": 8,
            "servingSizeUnit": "fl oz",
            "foodNutrients": [
                { "nutrientName": "Energy", "unitName": "KCAL", "value": 45 }
            ]
        }
        """
        let food = try decodeUSDAFood(json)
        let result = food.asFoodResult()

        #expect(result.servingSizeGrams == 100)
        #expect(isClose(result.calories, 45))
    }

    @Test
    func usdaFoodNutrientLookupIsCaseInsensitiveOnName() throws {
        let json = """
        {
            "fdcId": 789,
            "description": "Test Food",
            "foodNutrients": [
                { "nutrientName": "energy", "unitName": "kcal", "value": 50 }
            ]
        }
        """
        let food = try decodeUSDAFood(json)
        #expect(isClose(food.asFoodResult().calories, 50))
    }

    // MARK: - Barcode normalization

    @Test
    func normalizeUPCStripsLeadingZerosSoUPCAAndEANFormsMatch() {
        let service = FoodLookupService.shared
        #expect(service.normalizeUPC("012345678905") == service.normalizeUPC("12345678905"))
        #expect(service.normalizeUPC("0000") == "0")
        #expect(service.normalizeUPC("00012") == "12")
    }
}
