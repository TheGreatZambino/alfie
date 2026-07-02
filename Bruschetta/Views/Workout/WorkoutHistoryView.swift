import SwiftUI
import SwiftData

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        List {
            ForEach(sessions) { session in
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
                            .foregroundStyle(Color.appAccent)
                        Text("\(session.exerciseCount) exercise\(session.exerciseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        delete(session)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if sessions.isEmpty {
                ContentUnavailableView("No Workouts Yet", systemImage: "figure.strengthtraining.traditional", description: Text("Workouts you log will show up here."))
            }
        }
    }

    private func delete(_ session: WorkoutSession) {
        modelContext.delete(session)
        try? modelContext.save()
    }
}
