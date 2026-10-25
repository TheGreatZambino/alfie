import Foundation
import SwiftData

@Model
final class Recipe {
    var name: String = ""
    var summary: String = ""
    var servings: Int = 2
    var prepMinutes: Int = 0
    /// One ingredient per line.
    var ingredientsText: String = ""
    /// One step per line.
    var stepsText: String = ""
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date = Date()

    init(name: String, summary: String = "", servings: Int = 2, prepMinutes: Int = 0,
         ingredientsText: String = "", stepsText: String = "", imageData: Data? = nil) {
        self.name = name
        self.summary = summary
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.ingredientsText = ingredientsText
        self.stepsText = stepsText
        self.imageData = imageData
    }

    var ingredients: [String] { Recipe.lines(ingredientsText) }
    var steps: [String] { Recipe.lines(stepsText) }

    /// "45 min", "2 hr", "1 hr 42 min".
    static func formatDuration(minutes: Int) -> String {
        let hours = minutes / 60, mins = minutes % 60
        switch (hours, mins) {
        case (0, _): return "\(mins) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(mins) min"
        }
    }

    static func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Adds every ingredient to the active shopping list, skipping ones already on it.
    /// Returns how many were added.
    @discardableResult
    static func addIngredients(of recipe: Recipe, to context: ModelContext) -> Int {
        let existing = (try? context.fetch(FetchDescriptor<ShoppingItem>(predicate: #Predicate { $0.transaction == nil }))) ?? []
        var names = Set(existing.map { $0.name.lowercased() })
        var added = 0
        for ingredient in recipe.ingredients where names.insert(ingredient.lowercased()).inserted {
            context.insert(ShoppingItem(name: ingredient))
            added += 1
        }
        try? context.save()
        return added
    }

    static let samples: [(name: String, summary: String, servings: Int, prep: Int, ingredients: String, steps: String)] = [
        ("Garlic Butter Chicken & Rice", "Weeknight one-pan chicken over fluffy rice.", 4, 35,
         "1.5 lb chicken breast\n1 cup long-grain rice\n3 tbsp butter\n4 cloves garlic\n2 cups chicken broth\n1 tsp paprika\nSalt and pepper\nFresh parsley",
         "Season chicken with paprika, salt and pepper.\nSear chicken in butter 5 minutes per side, then remove.\nSauté garlic 30 seconds, add rice and broth.\nNestle chicken on top, cover and simmer 20 minutes.\nRest 5 minutes and garnish with parsley."),
        ("Greek Yogurt Berry Bowl", "Fast high-protein breakfast.", 1, 5,
         "1 cup Greek yogurt\n1/2 cup mixed berries\n2 tbsp granola\n1 tbsp honey",
         "Spoon yogurt into a bowl.\nTop with berries and granola.\nDrizzle with honey.")
    ]
}
