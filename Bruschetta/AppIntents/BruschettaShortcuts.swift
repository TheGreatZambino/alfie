import AppIntents

/// Registers the app's intents as Siri/Spotlight-discoverable shortcuts. Apple indexes
/// these at build time — no plist entries needed for in-app (non-widget) intents.
struct BruschettaShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .navy

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GoalStatusIntent(),
            phrases: [
                "How am I doing in \(.applicationName)",
                "Check my goals in \(.applicationName)",
                "How's my week in \(.applicationName)"
            ],
            shortTitle: "Check Goals",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add an expense to \(.applicationName)",
                "Log a purchase in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "creditcard.fill"
        )
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Log a meal in \(.applicationName)"
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )
        AppShortcut(
            intent: LogWorkoutIntent(),
            phrases: [
                "Log a workout in \(.applicationName)",
                "Log my workout in \(.applicationName)"
            ],
            shortTitle: "Log Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
