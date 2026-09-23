import Foundation
import Combine

// MARK: - Display text normalization

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }

    /// USDA descriptions are stored ALL CAPS, and some Open Food Facts entries are
    /// submitted the same way. Title-cases text that reads as fully uppercase while
    /// leaving already mixed-case text (most Open Food Facts entries) untouched.
    var normalizedFoodText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = trimmed.filter { $0.isLetter }
        guard !letters.isEmpty, letters == letters.uppercased() else { return trimmed }
        return trimmed.capitalized(with: Locale(identifier: "en_US"))
    }
}

/// Normalizes a raw serving-size label like "28G" or "1.5 OZ" into consistent spacing
/// and lowercase units. Leaves richer free-text labels (e.g. "1 bar (28 g)") as-is rather
/// than risk mangling them, and falls back to a computed gram string when there's no label.
private func normalizedServingDescription(rawText: String?, grams: Double) -> String {
    guard let rawText, !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return OFFProduct.formatGrams(grams)
    }
    let pattern = #"^\s*([\d.]+)\s*([a-zA-Z]+)\s*$"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: rawText, range: NSRange(rawText.startIndex..., in: rawText)),
       let numberRange = Range(match.range(at: 1), in: rawText),
       let unitRange = Range(match.range(at: 2), in: rawText) {
        return "\(rawText[numberRange]) \(rawText[unitRange].lowercased())"
    }
    return rawText
}

struct FoodResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String?
    let source: FoodSource
    let externalId: String?
    let barcode: String?
    let servingSizeGrams: Double
    let servingDescription: String
    /// Alternate ways to log this food (e.g. its labeled serving alongside a flat 100 g
    /// reference), always non-empty and led by `servingDescription`/`servingSizeGrams`.
    let servingOptions: [ServingOption]
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let sugarGrams: Double
    let fiberGrams: Double
    let sodiumMilligrams: Double
}

/// One selectable way to log a food's amount — a label ("1 cup", "100 g") paired with
/// its gram weight. Mirrors how MyFitnessPal lets a food carry several servings instead
/// of a single fixed one.
struct ServingOption: Identifiable, Hashable, Codable {
    var description: String
    var grams: Double

    var id: String { "\(description)|\(grams)" }
}

/// Builds the default+100g serving option list shared by both food sources: the food's
/// labeled/natural serving first, with a flat 100 g reference appended when it's meaningfully
/// different (so a food whose natural serving already *is* ~100g doesn't show a duplicate).
private func buildServingOptions(primaryDescription: String, primaryGrams: Double) -> [ServingOption] {
    var options = [ServingOption(description: primaryDescription, grams: primaryGrams)]
    if abs(primaryGrams - 100) > 1 {
        options.append(ServingOption(description: "100 g", grams: 100))
    }
    return options
}

@MainActor
final class FoodLookupService: ObservableObject {
    static let shared = FoodLookupService()

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let session = URLSession.shared

    func lookupBarcode(_ barcode: String) async -> FoodResult? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // USDA's branded food data is QA'd and matched by exact GTIN, so it's tried first;
        // Open Food Facts is community-submitted and more prone to mislabeled or bad entries.
        if let result = try? await fetchUSDAByBarcode(barcode) {
            return result
        }
        if let result = try? await fetchOpenFoodFactsProduct(barcode: barcode) {
            return result
        }
        return nil
    }

    func search(query: String) async -> [FoodResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let usda: [FoodResult] = (try? fetchUSDASearch(query: query)) ?? []
        async let off: [FoodResult] = (try? fetchOpenFoodFactsSearch(query: query)) ?? []

        let usdaResults = await usda
        let offResults = await off

        if usdaResults.isEmpty && offResults.isEmpty {
            errorMessage = "No results found."
        }

        var seen = Set<String>()
        var merged: [FoodResult] = []
        for result in usdaResults + offResults {
            if seen.insert(Self.dedupKey(for: result)).inserted {
                merged.append(result)
            }
        }
        return Array(merged.prefix(30))
    }

    /// A barcode is a much stronger identity signal than name/brand text, so two results
    /// sharing one (e.g. the same product returned by both USDA and Open Food Facts) are
    /// treated as duplicates even if their descriptions read differently. Otherwise falls
    /// back to normalized name+brand text — punctuation/whitespace stripped and lowercased,
    /// so "Chicken Breast," and "chicken breast" collapse to the same key.
    private static func dedupKey(for result: FoodResult) -> String {
        if let barcode = result.barcode, !barcode.isEmpty {
            return "barcode:\(barcode)"
        }
        return "text:\(normalizeForDedup(result.name))|\(normalizeForDedup(result.brand ?? ""))"
    }

    private static func normalizeForDedup(_ text: String) -> String {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Open Food Facts

    private func fetchOpenFoodFactsProduct(barcode: String) async throws -> FoodResult? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json") else { return nil }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: data)
        guard response.status == 1, let product = response.product else { return nil }
        return product.asFoodResult(barcode: barcode)
    }

    private func fetchOpenFoodFactsSearch(query: String) async throws -> [FoodResult] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20")
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
        return response.products.compactMap { $0.asFoodResult(barcode: $0.code) }
    }

    // MARK: - USDA FoodData Central

    /// FDC's search endpoint is free-text and only matches a barcode by coincidence
    /// (it's not indexed as a GTIN lookup), so results must be filtered down to a food
    /// whose actual `gtinUpc` field equals the scanned barcode before trusting a match.
    private func fetchUSDAByBarcode(_ barcode: String) async throws -> FoodResult? {
        guard !Secrets.usdaAPIKey.isEmpty else { return nil }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: Secrets.usdaAPIKey),
            URLQueryItem(name: "query", value: barcode),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: "20")
        ]
        guard let url = components.url else { return nil }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        let normalizedBarcode = normalizeUPC(barcode)
        let match = response.foods.first { food in
            guard let gtinUpc = food.gtinUpc else { return false }
            return normalizeUPC(gtinUpc) == normalizedBarcode
        }
        return match?.asFoodResult()
    }

    /// Strips leading zeros so a 12-digit UPC-A and its zero-padded 13-digit EAN form compare equal.
    func normalizeUPC(_ code: String) -> String {
        let trimmed = code.drop { $0 == "0" }
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    private func fetchUSDASearch(query: String) async throws -> [FoodResult] {
        guard !Secrets.usdaAPIKey.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: Secrets.usdaAPIKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "20")
        ]
        guard let url = components.url else { return [] }
        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return response.foods.map { $0.asFoodResult() }
    }
}

// MARK: - Open Food Facts response models

private struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
}

struct OFFProduct: Decodable {
    let code: String?
    let product_name: String?
    let brands: String?
    let serving_size: String?
    let serving_quantity: Double?
    let nutriments: OFFNutriments?

    /// Defaults the logged amount to the product's labeled serving (e.g. "1 bar (28g)")
    /// rather than the 100g the underlying nutrient fields are normalized to — falling
    /// back to `serving_size`'s free-text grams, then to 100g if neither is available.
    func asFoodResult(barcode: String?) -> FoodResult? {
        guard let name = product_name, !name.isEmpty, let nutriments else { return nil }
        let servingGrams = serving_quantity ?? Self.parseGrams(from: serving_size) ?? 100
        let scale = servingGrams / 100
        let servingDescription = normalizedServingDescription(rawText: serving_size, grams: servingGrams)
        return FoodResult(
            name: name.normalizedFoodText,
            brand: brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces).normalizedFoodText,
            source: .openFoodFacts,
            externalId: barcode,
            barcode: barcode,
            servingSizeGrams: servingGrams,
            servingDescription: servingDescription,
            servingOptions: buildServingOptions(primaryDescription: servingDescription, primaryGrams: servingGrams),
            calories: nutriments.energy_kcal_serving ?? (nutriments.energy_kcal_100g ?? 0) * scale,
            proteinGrams: nutriments.proteins_serving ?? (nutriments.proteins_100g ?? 0) * scale,
            carbsGrams: nutriments.carbohydrates_serving ?? (nutriments.carbohydrates_100g ?? 0) * scale,
            fatGrams: nutriments.fat_serving ?? (nutriments.fat_100g ?? 0) * scale,
            sugarGrams: nutriments.sugars_serving ?? (nutriments.sugars_100g ?? 0) * scale,
            fiberGrams: nutriments.fiber_serving ?? (nutriments.fiber_100g ?? 0) * scale,
            sodiumMilligrams: (nutriments.sodium_serving ?? (nutriments.sodium_100g ?? 0) * scale) * 1000
        )
    }

    static func parseGrams(from text: String?) -> Double? {
        guard let text, let match = text.range(of: #"[\d.]+\s*g\b"#, options: .regularExpression) else { return nil }
        return Double(text[match].filter { $0.isNumber || $0 == "." })
    }

    static func formatGrams(_ value: Double) -> String {
        let grams = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
        return "\(grams) g"
    }
}

struct OFFNutriments: Decodable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let sugars_100g: Double?
    let fiber_100g: Double?
    let sodium_100g: Double?
    let energy_kcal_serving: Double?
    let proteins_serving: Double?
    let carbohydrates_serving: Double?
    let fat_serving: Double?
    let sugars_serving: Double?
    let fiber_serving: Double?
    let sodium_serving: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g, carbohydrates_100g, fat_100g, sugars_100g, fiber_100g, sodium_100g
        case energy_kcal_serving = "energy-kcal_serving"
        case proteins_serving, carbohydrates_serving, fat_serving, sugars_serving, fiber_serving, sodium_serving
    }
}

// MARK: - USDA response models

private struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let brandName: String?
    let gtinUpc: String?
    let servingSize: Double?
    let servingSizeUnit: String?
    /// Branded foods carry a human-readable label serving (e.g. "1 cup (240 mL)")
    /// alongside `servingSize`/`servingSizeUnit`'s raw numeric form.
    let householdServingFullText: String?
    let foodNutrients: [USDANutrient]

    /// USDA's `foodNutrients` values in search results are always normalized per 100g,
    /// regardless of what `servingSize`/`servingSizeUnit` (the label's serving size) says —
    /// so the label serving is used only to size the default logged amount, scaling the
    /// per-100g nutrient values down (or up) to match.
    func asFoodResult() -> FoodResult {
        func value(for nutrientName: String, unit: String? = nil) -> Double {
            foodNutrients.first {
                $0.nutrientName?.localizedCaseInsensitiveContains(nutrientName) == true
                    && (unit == nil || $0.unitName?.caseInsensitiveCompare(unit!) == .orderedSame)
            }?.value ?? 0
        }

        let servingGrams: Double
        if let servingSize, servingSize > 0 {
            // Exact-match the unit rather than substring-matching "g", which previously
            // also matched "mg" (and would've matched "kg") and silently mistreated
            // milligram/kilogram servings as gram servings.
            switch servingSizeUnit?.lowercased() {
            case "g", "gram", "grams":
                servingGrams = servingSize
            case "kg", "kilogram", "kilograms":
                servingGrams = servingSize * 1000
            case "mg", "milligram", "milligrams":
                servingGrams = servingSize / 1000
            case "oz", "ounce", "ounces":
                servingGrams = servingSize * 28.3495
            case "lb", "lbs", "pound", "pounds":
                servingGrams = servingSize * 453.592
            default:
                // Units like "ml" or "IU" aren't a reliable weight conversion; fall back.
                servingGrams = 100
            }
        } else {
            servingGrams = 100
        }
        let scale = servingGrams / 100
        // Prefer the label's household measure ("1 cup") as the display description when
        // present; it's far more useful to log against than a bare gram figure.
        let servingDescription = householdServingFullText?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? (servingGrams.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(servingGrams)) g" : String(format: "%.1f g", servingGrams))

        return FoodResult(
            name: description.normalizedFoodText,
            brand: brandName?.normalizedFoodText,
            source: .usda,
            externalId: String(fdcId),
            barcode: gtinUpc,
            servingSizeGrams: servingGrams,
            servingDescription: servingDescription,
            servingOptions: buildServingOptions(primaryDescription: servingDescription, primaryGrams: servingGrams),
            calories: value(for: "Energy", unit: "KCAL") * scale,
            proteinGrams: value(for: "Protein") * scale,
            carbsGrams: value(for: "Carbohydrate") * scale,
            fatGrams: value(for: "Total lipid") * scale,
            sugarGrams: value(for: "Sugars") * scale,
            fiberGrams: value(for: "Fiber") * scale,
            sodiumMilligrams: value(for: "Sodium") * scale
        )
    }
}

struct USDANutrient: Decodable {
    let nutrientName: String?
    let unitName: String?
    let value: Double?
}
