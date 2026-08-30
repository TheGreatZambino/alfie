import WidgetKit
import SwiftUI

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

struct AlfieHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshotStore.homeWidgetKind, provider: WorkoutTimelineProvider()) { entry in
            WidgetHomeView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) {
                    Color(.systemBackground)
                }
        }
        .configurationDisplayName("Today's Overview")
        .description("Shows today's workouts, finances, and nutrition at a glance.")
        .supportedFamilies([.systemLarge])
    }
}
