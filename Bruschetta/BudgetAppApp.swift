import SwiftUI
import SwiftData

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
    }

    var sharedModelContainer: ModelContainer = AppModelContainer.shared

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
