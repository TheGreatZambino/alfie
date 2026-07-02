import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    @ObservedObject private var health = HealthKitManager.shared
    @State private var showNewTemplate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    CardioCard(health: health)

                    TemplatesCard(templates: templates, showNewTemplate: $showNewTemplate)

                    RecentWorkoutsCard(items: recentWorkoutItems)
                }
                .padding()
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewTemplate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewTemplate) {
                NewTemplateView()
            }
            .task {
                if health.isAuthorized {
                    await health.fetchRecentWorkouts()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("This Week")
                .font(.title2.bold())
            Text("\(sessionsThisWeek) strength session\(sessionsThisWeek == 1 ? "" : "s") · \(cardioMinutesThisWeek) cardio min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sessionsThisWeek: Int {
        let calendar = Calendar.current
        return sessions.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }

    private var cardioMinutesThisWeek: Int {
        let calendar = Calendar.current
        let total = health.recentWorkouts
            .filter { calendar.isDate($0.startDate, equalTo: Date(), toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.duration }
        return Int(total / 60)
    }

    private var recentWorkoutItems: [RecentWorkoutItem] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -3, to: Date()) else { return [] }
        let strengthItems = sessions.filter { $0.date >= cutoff }.map(RecentWorkoutItem.strength)
        let cardioItems = health.recentWorkouts.filter { $0.startDate >= cutoff }.map(RecentWorkoutItem.cardio)
        return (strengthItems + cardioItems).sorted { $0.date > $1.date }
    }
}

private enum RecentWorkoutItem: Identifiable {
    case strength(WorkoutSession)
    case cardio(CardioWorkout)

    var id: AnyHashable {
        switch self {
        case .strength(let session): return session.id
        case .cardio(let workout): return workout.id
        }
    }

    var date: Date {
        switch self {
        case .strength(let session): return session.date
        case .cardio(let workout): return workout.startDate
        }
    }
}

// MARK: - Cardio

private struct CardioCard: View {
    @ObservedObject var health: HealthKitManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cardio")
                    .font(.headline)
                Spacer()
                if health.isLoading {
                    ProgressView()
                }
            }

            if !health.isHealthDataAvailable {
                Text("Health data isn't available on this device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !health.isAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Connect your Apple Health data to bring in workouts from other devices/apps such as Garmin, Strava, etc")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await health.requestAuthorizationAndFetch() }
                    } label: {
                        Text("Connect Apple Health")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appAccent)
                }
            } else if let error = health.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if health.recentWorkouts.isEmpty {
                Text("No cardio workouts found in Health yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let recent = Array(health.recentWorkouts.prefix(5))
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, workout in
                    CardioWorkoutRow(workout: workout)
                    if index != recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

private struct CardioWorkoutRow: View {
    let workout: CardioWorkout

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: workout.activityType.symbolName)
                    .foregroundStyle(Color.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityType.displayName)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationText)
                    .font(.subheadline)
                if let calories = workout.activeCalories {
                    Text("\(Int(calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [workout.startDate.formatted(.dateTime.month(.abbreviated).day())]
        if let distance = workout.distanceMiles, distance > 0.05 {
            parts.append(String(format: "%.2f mi", distance))
        }
        parts.append(workout.sourceName)
        return parts.joined(separator: " · ")
    }

    private var durationText: String {
        "\(Int(workout.duration / 60)) min"
    }
}

// MARK: - Templates

private struct TemplatesCard: View {
    let templates: [WorkoutTemplate]
    @Binding var showNewTemplate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Strength Templates")
                    .font(.headline)
                Spacer()
                Button {
                    showNewTemplate = true
                } label: {
                    Label("New", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
            }

            if templates.isEmpty {
                Text("Save a template to run the same lifts every time without re-entering sets and reps.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(templates) { template in
                            TemplateTile(template: template)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

private struct TemplateTile: View {
    let template: WorkoutTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(template.name)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("\(template.sortedEntries.count) exercise\(template.sortedEntries.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 140, alignment: .leading)
        .background(Color.appAccent.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Recent sessions

private struct RecentWorkoutsCard: View {
    let items: [RecentWorkoutItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Workouts")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    WorkoutHistoryView()
                }
                .font(.subheadline)
            }

            if items.isEmpty {
                Text("No workouts in the last three days. Log one to start tracking!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    switch item {
                    case .strength(let session):
                        StrengthSessionRow(session: session)
                    case .cardio(let workout):
                        CardioWorkoutRow(workout: workout)
                    }
                    if index != items.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

private struct StrengthSessionRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.subheadline.bold())
                Text(session.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(session.totalVolume)) lb")
                .font(.subheadline)
                .foregroundStyle(Color.appAccent)
        }
    }
}
