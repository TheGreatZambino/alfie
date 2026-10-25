import Foundation

nonisolated struct ImportedRecipe {
    var name: String
    var summary: String
    var servings: Int
    var prepMinutes: Int
    var ingredients: [String]
    var steps: [String]
    var imageURL: URL?
}

enum RecipeImportError: LocalizedError {
    case invalidURL, network, noRecipe

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "That doesn't look like a web link."
        case .network: return "Couldn't load that page. Check the link and your connection."
        case .noRecipe: return "We couldn't find a recipe on that page. Some sites need a login or don't allow importing."
        }
    }
}

/// Imports a recipe from any page that publishes schema.org `Recipe` JSON-LD markup.
nonisolated enum RecipeImportService {
    static func importRecipe(from text: String) async throws -> (ImportedRecipe, Data?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed.contains("://") ? trimmed : "https://" + trimmed),
              let host = components.host, host.contains("."),
              ["http", "https"].contains(components.scheme?.lowercased() ?? "") else {
            throw RecipeImportError.invalidURL
        }
        components.scheme = "https"
        guard let url = components.url else { throw RecipeImportError.invalidURL }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        let html: String
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw RecipeImportError.network }
            html = String(decoding: data, as: UTF8.self)
        } catch let error as RecipeImportError {
            throw error
        } catch {
            throw RecipeImportError.network
        }

        guard let recipe = parse(html: html) else { throw RecipeImportError.noRecipe }
        var imageData: Data?
        if let imageURL = recipe.imageURL, let (data, _) = try? await URLSession.shared.data(from: imageURL) {
            imageData = data
        }
        return (recipe, imageData)
    }

    // MARK: Parsing (internal for tests)

    static func parse(html: String) -> ImportedRecipe? {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard let r = Range(match.range(at: 1), in: html),
                  let data = html[r].data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let node = findRecipe(in: json) else { continue }
            if let recipe = build(from: node) { return recipe }
        }
        return nil
    }

    private static func isRecipe(_ dict: [String: Any]) -> Bool {
        if let type = dict["@type"] as? String { return type == "Recipe" }
        if let types = dict["@type"] as? [String] { return types.contains("Recipe") }
        return false
    }

    private static func findRecipe(in json: Any) -> [String: Any]? {
        if let array = json as? [Any] {
            for item in array { if let found = findRecipe(in: item) { return found } }
        } else if let dict = json as? [String: Any] {
            if isRecipe(dict) { return dict }
            if let graph = dict["@graph"] { return findRecipe(in: graph) }
        }
        return nil
    }

    private static func build(from node: [String: Any]) -> ImportedRecipe? {
        guard let rawName = node["name"] as? String else { return nil }
        let ingredients = (node["recipeIngredient"] as? [String] ?? (node["recipeIngredient"] as? String).map { [$0] } ?? [])
            .map(clean).filter { !$0.isEmpty }
        let steps = instructions(node["recipeInstructions"]).map(clean).filter { !$0.isEmpty }
        guard !ingredients.isEmpty || !steps.isEmpty else { return nil }

        var name = clean(rawName)
        for suffix in [" Recipe by Tasty", " by Tasty"] where name.hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }

        let total = minutes(node["totalTime"] as? String) ?? minutes(node["cookTime"] as? String) ?? minutes(node["prepTime"] as? String) ?? 0
        return ImportedRecipe(
            name: name,
            summary: clean(node["description"] as? String ?? ""),
            servings: servings(node["recipeYield"]),
            prepMinutes: total,
            ingredients: ingredients,
            steps: steps,
            imageURL: imageURL(node["image"])
        )
    }

    private static func instructions(_ value: Any?) -> [String] {
        if let text = value as? String {
            return text.split(whereSeparator: \.isNewline).map(String.init)
        }
        if let array = value as? [Any] { return array.flatMap(instructions) }
        if let dict = value as? [String: Any] {
            if let items = dict["itemListElement"] { return instructions(items) }
            if let text = dict["text"] as? String { return [text] }
            if let name = dict["name"] as? String { return [name] }
        }
        return []
    }

    private static func imageURL(_ value: Any?) -> URL? {
        if let s = value as? String { return URL(string: s) }
        if let a = value as? [Any] { return a.lazy.compactMap(imageURL).first }
        if let d = value as? [String: Any] { return imageURL(d["url"]) }
        return nil
    }

    private static func servings(_ value: Any?) -> Int {
        let text: String
        if let n = value as? Int { return max(n, 1) }
        if let a = value as? [Any], let first = a.first { return servings(first) }
        text = value as? String ?? ""
        let digits = text.drop { !$0.isNumber }.prefix { $0.isNumber }
        return max(Int(digits) ?? 2, 1)
    }

    /// Parses ISO 8601 durations like "PT1H30M".
    private static func minutes(_ iso: String?) -> Int? {
        guard let iso, iso.hasPrefix("P") else { return nil }
        var total = 0, number = ""
        var inTime = false
        for c in iso.dropFirst() {
            if c == "T" { inTime = true }
            else if c.isNumber { number.append(c) }
            else {
                let n = Int(number) ?? 0
                switch (c, inTime) {
                case ("D", _): total += n * 1440
                case ("H", true): total += n * 60
                case ("M", true): total += n
                default: break
                }
                number = ""
            }
        }
        return total > 0 ? total : nil
    }

    private static func clean(_ s: String) -> String {
        var text = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (entity, char) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
