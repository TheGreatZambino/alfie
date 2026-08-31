import SwiftUI
import SwiftData
import CoreData

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct BudgetAppApp: App {
    init() {
        AnalyticsService.configure()
        _ = SubscriptionManager.shared
        GoogleMobileAdsInitializer.start()
        CrashDiagnosticsReporter.shared.start()
    }

    var sharedModelContainer: ModelContainer = {
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
    }()

    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearanceMode.colorScheme)
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
