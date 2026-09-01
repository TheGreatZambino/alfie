import SwiftData
import CoreData

/// Single source of truth for the app's `ModelContainer`, shared by the main app and
/// by App Intents (which run in-process but outside the SwiftUI environment, so they
/// can't reach `.modelContainer(_:)`).
enum AppModelContainer {
    static let shared: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )

        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            // Incompatible on-disk store from an older schema (failed migration).
            // Rather than crash on every launch, wipe the local store and start fresh.
            let storeURL = modelConfiguration.url
            if FileManager.default.fileExists(atPath: storeURL.path) {
                let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
                try? coordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
            }

            if let retried = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return retried
            }
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
