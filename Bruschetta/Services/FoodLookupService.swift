import Foundation
import Combine

struct FoodResult: Identifiable {
    let id = UUID()
    let name: String
    let brand: String?
    let source: FoodSource
    let externalId: String?
    let barcode: String?
    let servingSizeGrams: Double
    let servingDescription: String
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let sugarGrams: Double
    let fiberGrams: Double
    let sodiumMilligrams: Double
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
            let key = "\(result.name.lowercased())|\(result.brand?.lowercased() ?? "")"
            if seen.insert(key).inserted {
                merged.append(result)
            }
        }
        return Array(merged.prefix(30))
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
    private func normalizeUPC(_ code: String) -> String {
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

private struct OFFProduct: Decodable {
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
        return FoodResult(
            name: name,
            brand: brands?.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces),
            source: .openFoodFacts,
            externalId: barcode,
            barcode: barcode,
            servingSizeGrams: servingGrams,
            servingDescription: serving_size ?? Self.formatGrams(servingGrams),
            calories: nutriments.energy_kcal_serving ?? (nutriments.energy_kcal_100g ?? 0) * scale,
            proteinGrams: nutriments.proteins_serving ?? (nutriments.proteins_100g ?? 0) * scale,
            carbsGrams: nutriments.carbohydrates_serving ?? (nutriments.carbohydrates_100g ?? 0) * scale,
            fatGrams: nutriments.fat_serving ?? (nutriments.fat_100g ?? 0) * scale,
            sugarGrams: nutriments.sugars_serving ?? (nutriments.sugars_100g ?? 0) * scale,
            fiberGrams: nutriments.fiber_serving ?? (nutriments.fiber_100g ?? 0) * scale,
            sodiumMilligrams: (nutriments.sodium_serving ?? (nutriments.sodium_100g ?? 0) * scale) * 1000
        )
    }

    private static func parseGrams(from text: String?) -> Double? {
        guard let text, let match = text.range(of: #"[\d.]+\s*g\b"#, options: .regularExpression) else { return nil }
        return Double(text[match].filter { $0.isNumber || $0 == "." })
    }

    private static func formatGrams(_ value: Double) -> String {
        let grams = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
        return "\(grams) g"
    }
}

private struct OFFNutriments: Decodable {
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

private struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let brandName: String?
    let gtinUpc: String?
    let servingSize: Double?
    let servingSizeUnit: String?
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
        if let servingSize, servingSize > 0, servingSizeUnit?.lowercased().contains("g") == true {
            servingGrams = servingSize
        } else {
            servingGrams = 100
        }
        let scale = servingGrams / 100

        return FoodResult(
            name: description,
            brand: brandName,
            source: .usda,
            externalId: String(fdcId),
            barcode: gtinUpc,
            servingSizeGrams: servingGrams,
            servingDescription: servingGrams.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(servingGrams)) g" : String(format: "%.1f g", servingGrams),
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

private struct USDANutrient: Decodable {
    let nutrientName: String?
    let unitName: String?
    let value: Double?
}
