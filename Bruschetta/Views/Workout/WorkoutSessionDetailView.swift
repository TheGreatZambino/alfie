import SwiftUI
import SwiftData

struct WorkoutSessionDetailView: View {
    let session: WorkoutSession

    private var groupedEntries: [(exercise: Exercise, sets: [LoggedSet])] {
        var order: [Exercise] = []
        var byExercise: [PersistentIdentifier: [LoggedSet]] = [:]
        for loggedSet in (session.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
            guard let exercise = loggedSet.exercise else { continue }
            if byExercise[exercise.id] == nil {
                order.append(exercise)
                byExercise[exercise.id] = []
            }
            byExercise[exercise.id]?.append(loggedSet)
        }
        return order.map { ($0, byExercise[$0.id] ?? []) }
    }

    private var durationText: String {
        let total = Int(session.durationSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%dh %02dm", hours, minutes) }
        if minutes > 0 { return String(format: "%dm %02ds", minutes, seconds) }
        return "\(seconds)s"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard

                ForEach(groupedEntries, id: \.exercise.id) { entry in
                    exerciseCard(entry)
                }
            }
            .padding()
        }
        .background(Color.paper)
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(Color.inkTertiary)

            HStack(spacing: 10) {
                summaryStat(label: "Duration", value: durationText)
                summaryStat(label: "Volume", value: "\(Int(session.totalVolume)) lb")
                summaryStat(label: "Exercises", value: "\(session.exerciseCount)")
            }

            if session.prCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(Color.workoutGold)
                    Text("\(session.prCount) new PR\(session.prCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ink)
                }
            }
        }
        .cardStyle()
    }

    private func summaryStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.inkTertiary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exerciseCard(_ entry: (exercise: Exercise, sets: [LoggedSet])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconBadge(systemName: entry.exercise.muscleGroup.icon, color: .training, size: 34)
                Text(entry.exercise.name)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, loggedSet in
                    HStack {
                        Text("Set \(index + 1)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.inkTertiary)
                        Spacer()
                        if loggedSet.isPR {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.workoutGold)
                        }
                        Text(setSummary(loggedSet))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.ink)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(loggedSet.isPR ? Color.workoutGold.opacity(0.12) : Color.fill))
                }
            }
        }
        .cardStyle()
    }

    private func setSummary(_ loggedSet: LoggedSet) -> String {
        guard loggedSet.trackingType == .time else {
            return "\(Int(loggedSet.weight)) lb × \(loggedSet.reps)"
        }
        let minutes = loggedSet.durationSeconds / 60
        let seconds = loggedSet.durationSeconds % 60
        let durationText = minutes > 0 ? String(format: "%d:%02d", minutes, seconds) : "\(seconds)s"
        if loggedSet.weight > 0 {
            return "\(Int(loggedSet.weight)) lb × \(durationText)"
        }
        return durationText
    }
}
