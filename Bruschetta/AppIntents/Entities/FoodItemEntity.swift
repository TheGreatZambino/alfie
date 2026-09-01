import AppIntents
import SwiftData

/// Siri-visible wrapper around a `FoodItem`, scoped to items already in the user's
/// library (custom foods or anything looked up before) so Siri can resolve them by name.
struct FoodItemEntity: AppEntity {
    /// Base64-encoded `PersistentIdentifier` — see `PersistentIdentifier.appEntityID`.
    let id: String
    let name: String
    let brand: String?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Food"
    static var defaultQuery = FoodItemEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        if let brand {
            DisplayRepresentation(title: "\(name)", subtitle: "\(brand)")
        } else {
            DisplayRepresentation(title: "\(name)")
        }
    }
}

struct FoodItemEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [FoodItemEntity] {
        let context = ModelContext(AppModelContainer.shared)
        return identifiers.compactMap { id in
            guard let persistentID = PersistentIdentifier.from(appEntityID: id),
                  let item = context.model(for: persistentID) as? FoodItem else { return nil }
            return FoodItemEntity(id: id, name: item.name, brand: item.brand)
        }
    }

    @MainActor
    func entities(matching string: String) async throws -> [FoodItemEntity] {
        let context = ModelContext(AppModelContainer.shared)
        let descriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate { $0.name.localizedStandardContains(string) },
            sortBy: [SortDescriptor(\.name)]
        )
        let items = try context.fetch(descriptor)
        return items.prefix(20).map { FoodItemEntity(id: $0.persistentModelID.appEntityID, name: $0.name, brand: $0.brand) }
    }

    @MainActor
    func suggestedEntities() async throws -> [FoodItemEntity] {
        let context = ModelContext(AppModelContainer.shared)
        var descriptor = FetchDescriptor<FoodItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 10
        let items = try context.fetch(descriptor)
        return items.map { FoodItemEntity(id: $0.persistentModelID.appEntityID, name: $0.name, brand: $0.brand) }
    }
}
