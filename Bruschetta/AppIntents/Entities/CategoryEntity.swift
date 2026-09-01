import AppIntents
import SwiftData

/// Siri-visible wrapper around a spending `Category`, so users can refer to categories
/// by name ("log this to Groceries") instead of only by app-specific IDs.
struct CategoryEntity: AppEntity {
    /// Base64-encoded `PersistentIdentifier` — see `PersistentIdentifier.appEntityID`.
    let id: String
    let name: String
    let icon: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static var defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: icon))
    }
}

struct CategoryEntityQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [CategoryEntity] {
        let context = ModelContext(AppModelContainer.shared)
        return identifiers.compactMap { id in
            guard let persistentID = PersistentIdentifier.from(appEntityID: id),
                  let category = context.model(for: persistentID) as? Category else { return nil }
            return CategoryEntity(id: id, name: category.name, icon: category.icon)
        }
    }

    func entities(matching string: String) async throws -> [CategoryEntity] {
        try await spendingCategories().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [CategoryEntity] {
        try await spendingCategories()
    }

    private func spendingCategories() async throws -> [CategoryEntity] {
        let context = ModelContext(AppModelContainer.shared)
        let spending = CategoryType.spending.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.typeRaw == spending },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = try context.fetch(descriptor)
        return categories.map { CategoryEntity(id: $0.persistentModelID.appEntityID, name: $0.name, icon: $0.icon) }
    }
}
