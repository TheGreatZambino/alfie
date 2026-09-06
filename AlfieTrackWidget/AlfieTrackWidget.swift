import WidgetKit
import SwiftUI
import AppIntents

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetWorkoutSnapshot
}

struct WorkoutTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(
            date: Date(),
            snapshot: WidgetWorkoutSnapshot(
                strength: StrengthWorkoutSnapshot(name: "Push Day", date: Date(), totalVolume: 4200, exerciseCount: 5),
                cardio: CardioWorkoutSnapshot(activityName: "Run", date: Date(), durationMinutes: 32, distanceMiles: 3.1)
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutEntry) -> Void) {
        completion(WorkoutEntry(date: Date(), snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutEntry>) -> Void) {
        let entry = WorkoutEntry(date: Date(), snapshot: WidgetSnapshotStore.load())
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct AlfieTrackWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.widgetKind, provider: WorkoutTimelineProvider()) { entry in
            WidgetWorkoutView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Today's Workouts")
        .description("Shows your most recent strength and cardio workouts for today.")
        .supportedFamilies([.systemMedium])
    }
}

struct HomeWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetWorkoutSnapshot
    let configuration: HomeWidgetConfigurationIntent
}

struct HomeTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HomeWorkoutEntry {
        HomeWorkoutEntry(
            date: Date(),
            snapshot: WidgetWorkoutSnapshot(
                strength: StrengthWorkoutSnapshot(name: "Push Day", date: Date(), totalVolume: 4200, exerciseCount: 5),
                cardio: CardioWorkoutSnapshot(activityName: "Run", date: Date(), durationMinutes: 32, distanceMiles: 3.1),
                finance: FinanceSnapshot(incomeThisPeriod: 2000, remainingThisPeriod: 340, periodEnd: Date()),
                nutrition: NutritionSnapshot(caloriesToday: 1200, calorieGoal: 2000),
                water: WaterSnapshot(ouncesToday: 32, goalOunces: 64)
            ),
            configuration: HomeWidgetConfigurationIntent()
        )
    }

    func snapshot(for configuration: HomeWidgetConfigurationIntent, in context: Context) async -> HomeWorkoutEntry {
        HomeWorkoutEntry(date: Date(), snapshot: WidgetSnapshotStore.load(), configuration: configuration)
    }

    func timeline(for configuration: HomeWidgetConfigurationIntent, in context: Context) async -> Timeline<HomeWorkoutEntry> {
        let entry = HomeWorkoutEntry(date: Date(), snapshot: WidgetSnapshotStore.load(), configuration: configuration)
        let calendar = Calendar.current
        let nextMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextMidnight))
    }
}

struct AlfieHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetSnapshotStore.homeWidgetKind, intent: HomeWidgetConfigurationIntent.self, provider: HomeTimelineProvider()) { entry in
            WidgetHomeView(snapshot: entry.snapshot, configuration: entry.configuration)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Today's Overview")
        .description("Shows today's workouts, finances, nutrition, and water at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
