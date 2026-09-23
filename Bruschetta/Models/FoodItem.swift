import Foundation
import SwiftData

enum FoodSource: String, Codable, CaseIterable {
    case openFoodFacts
    case usda
    case custom
}

enum WeightUnit: String, CaseIterable, Identifiable {
    case grams = "g"
    case ounces = "oz"
    case pounds = "lb"

    var id: String { rawValue }

    var gramsPerUnit: Double {
        switch self {
        case .grams: return 1
        case .ounces: return 28.3495
        case .pounds: return 453.592
        }
    }
}

@Model
final class FoodItem {
    var name: String = ""
    var brand: String?
    var barcode: String?
    var sourceRaw: String = FoodSource.custom.rawValue
    var externalId: String?

    var servingSizeGrams: Double = 100
    var servingDescription: String = "100 g"
    /// JSON-encoded `[ServingOption]`. Use `servingOptions` to read/write.
    private var servingOptionsJSON: String = "[]"
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var sugarGrams: Double = 0
    var fiberGrams: Double = 0
    var sodiumMilligrams: Double = 0

    var isUserCreated: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \NutritionEntry.foodItem)
    var entries: [NutritionEntry]? = []

    init(name: String, brand: String? = nil, barcode: String? = nil, source: FoodSource, externalId: String? = nil,
         servingSizeGrams: Double = 100, servingDescription: String = "100 g", servingOptions: [ServingOption] = [],
         calories: Double = 0, proteinGrams: Double = 0, carbsGrams: Double = 0, fatGrams: Double = 0,
         sugarGrams: Double = 0, fiberGrams: Double = 0, sodiumMilligrams: Double = 0,
         isUserCreated: Bool = false) {
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.sourceRaw = source.rawValue
        self.externalId = externalId
        self.servingSizeGrams = servingSizeGrams
        self.servingDescription = servingDescription
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.sugarGrams = sugarGrams
        self.fiberGrams = fiberGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.isUserCreated = isUserCreated
        self.servingOptions = servingOptions.isEmpty
            ? [ServingOption(description: servingDescription, grams: servingSizeGrams)]
            : servingOptions
    }

    var source: FoodSource {
        get { FoodSource(rawValue: sourceRaw) ?? .custom }
        set { sourceRaw = newValue.rawValue }
    }

    /// Alternate ways to log this food (its labeled serving, a flat 100 g reference, etc).
    /// Falls back to a single option built from `servingDescription`/`servingSizeGrams` if
    /// nothing was ever encoded (e.g. items created before this field existed).
    var servingOptions: [ServingOption] {
        get {
            guard let data = servingOptionsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([ServingOption].self, from: data),
                  !decoded.isEmpty else {
                return [ServingOption(description: servingDescription, grams: servingSizeGrams)]
            }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue), let json = String(data: data, encoding: .utf8) else { return }
            servingOptionsJSON = json
        }
    }
}
