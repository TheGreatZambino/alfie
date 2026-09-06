import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @ObservedObject private var health = HealthKitManager.shared

    private var items: [RecentActivityItem] {
        let strengthItems = sessions.map { RecentActivityItem.strength($0) }
        let cardioItems = health.recentWorkouts.map { RecentActivityItem.cardio($0) }
        return (strengthItems + cardioItems)
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            ForEach(items) { item in
                row(for: item)
            }
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Workouts Yet", systemImage: "figure.strengthtraining.traditional", description: Text("Workouts you log will show up here."))
            }
        }
        .task {
            if health.isAuthorized {
                await health.fetchRecentWorkouts()
            }
        }
    }

    @ViewBuilder
    private func row(for item: RecentActivityItem) -> some View {
        switch item {
        case .strength(let session):
            NavigationLink {
                WorkoutSessionDetailView(session: session)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                            .font(.subheadline.bold())
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int(session.totalVolume)) lb")
                            .font(.subheadline)
                            .foregroundStyle(Color.training)
                        Text("\(session.exerciseCount) exercise\(session.exerciseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .swipeActions {
                Button(role: .destructive) {
                    delete(session)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        case .cardio(let workout):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.activityType.displayName)
                        .font(.subheadline.bold())
                    Text(workout.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(workout.duration / 60)) min")
                        .font(.subheadline)
                        .foregroundStyle(Color.training)
                    Text(workout.statsSummary ?? workout.sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func delete(_ session: WorkoutSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
}
