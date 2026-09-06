import SwiftUI
import SwiftData
import WidgetKit

struct WorkoutView: View {
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query private var workoutGoals: [WorkoutGoals]

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var health = HealthKitManager.shared
    @State private var showNewTemplate = false
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showStartWorkoutPicker = false
    @State private var showRepeatWorkoutPicker = false
    @State private var activePlan: WorkoutPlan?
    @State private var todaySteps = 0
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    StartCard(template: mostRecentTemplate, hasAnyTemplate: !templates.isEmpty, lastDoneDate: mostRecentTemplate != nil ? sessions.first?.date : nil) {
                        if let mostRecentTemplate {
                            activePlan = .template(mostRecentTemplate)
                        } else {
                            showStartWorkoutPicker = true
                        }
                    }

                    StatTilesRow(sessions: sessionsThisWeek, goal: workoutGoals.first?.weeklyStrengthGoal ?? 3, cardioMinutes: cardioMinutesThisWeek, steps: todaySteps)

                    TemplatesCard(templates: Array(templates.prefix(3)), mostRecentTemplateID: mostRecentTemplate?.id) { template in
                        activePlan = .template(template)
                    } onEdit: { template in
                        editingTemplate = template
                    } onNew: {
                        showNewTemplate = true
                    }

                    RecentCard(items: mergedRecentActivity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .background(Color.paper)
            .safeAreaInset(edge: .bottom) { AdSlot() }
            .toolbar(.hidden, for: .navigationBar)
            .tint(.training)
            .sheet(isPresented: $showNewTemplate) {
                NewTemplateView()
            }
            .sheet(item: $editingTemplate) { template in
                NewTemplateView(template: template)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showStartWorkoutPicker) {
                StartWorkoutPickerView(templates: templates) { template in
                    showStartWorkoutPicker = false
                    activePlan = .template(template)
                } onEdit: { template in
                    showStartWorkoutPicker = false
                    editingTemplate = template
                } onCreateNew: {
                    showStartWorkoutPicker = false
                    showNewTemplate = true
                } onStartFresh: {
                    showStartWorkoutPicker = false
                    activePlan = .fresh()
                } onRepeatWorkout: {
                    showStartWorkoutPicker = false
                    showRepeatWorkoutPicker = true
                }
            }
            .sheet(isPresented: $showRepeatWorkoutPicker) {
                RepeatWorkoutPickerView(sessions: sessions) { session in
                    showRepeatWorkoutPicker = false
                    activePlan = .repeating(session)
                }
            }
            .fullScreenCover(item: $activePlan) { plan in
                ActiveWorkoutView(plan: plan)
            }
            .task {
                await health.requestAuthorizationAndFetch()
                if health.isAuthorized {
                    await refreshTodaySteps()
                }
                refreshWidgetSnapshot()
            }
            .onAppear { refreshHealthData() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { refreshHealthData() }
            }
            .onChange(of: sessions) { refreshWidgetSnapshot() }
            .onChange(of: health.recentWorkouts) { refreshWidgetSnapshot() }
            .onChange(of: health.isAuthorized) { _, isAuthorized in
                if isAuthorized {
                    Task { await refreshTodaySteps() }
                }
            }
        }
    }

    private func refreshHealthData() {
        guard health.isAuthorized else { return }
        Task {
            await health.fetchRecentWorkouts()
            await refreshTodaySteps()
        }
    }

    private func refreshTodaySteps() async {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? Date()
        todaySteps = await health.fetchStepCount(in: DateInterval(start: start, end: end))
    }

    /// Publishes today's most recent strength/cardio workout to the App Group so the
    /// home screen widget (which can't query SwiftData or HealthKit itself) can show it.
    private func refreshWidgetSnapshot() {
        let calendar = Calendar.current
        let todaysSession = sessions
            .filter { calendar.isDateInToday($0.date) }
            .max { $0.date < $1.date }
        let todaysCardio = health.recentWorkouts
            .filter { calendar.isDateInToday($0.startDate) }
            .max { $0.startDate < $1.startDate }

        WidgetSnapshotStore.update { snapshot in
            snapshot.strength = todaysSession.map {
                StrengthWorkoutSnapshot(name: $0.name, date: $0.date, totalVolume: $0.totalVolume, exerciseCount: $0.exerciseCount)
            }
            snapshot.cardio = todaysCardio.map {
                CardioWorkoutSnapshot(activityName: $0.activityType.displayName, date: $0.startDate, durationMinutes: Int($0.duration / 60), distanceMiles: $0.distanceMiles)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshotStore.homeWidgetKind)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("WORKOUTS")
                    .eyebrowStyle(color: .training)
                Text(headlineText)
                    .font(.screenHeadline)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                NavigationLink {
                    WorkoutCalendarView()
                } label: {
                    Circle()
                        .fill(Color.card)
                        .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                        .overlay(
                            Image(systemName: "calendar")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.inkSecondary)
                        )
                        .frame(width: 36, height: 36)
                }
                Button {
                    showSettings = true
                } label: {
                    Circle()
                        .fill(Color.card)
                        .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                        .overlay(
                            Image(systemName: "gearshape")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.inkSecondary)
                        )
                        .frame(width: 36, height: 36)
                }
            }
        }
        .frame(minHeight: 84)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var headlineText: String {
        let goal = workoutGoals.first?.weeklyStrengthGoal ?? 3
        let remaining = goal - sessionsThisWeek
        if remaining <= 0 { return "You're on target" }
        return "One more this week"
    }

    /// Monday–Sunday, matching the "This Week" label, rather than the device locale's default first weekday.
    private var currentWeekInterval: DateInterval {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? Date()
        return DateInterval(start: start, end: end)
    }

    private var sessionsThisWeek: Int {
        let interval = currentWeekInterval
        return sessions.filter { interval.contains($0.date) }.count
    }

    private var cardioMinutesThisWeek: Int {
        let interval = currentWeekInterval
        let total = health.recentWorkouts
            .filter { interval.contains($0.startDate) }
            .reduce(0) { $0 + $1.duration }
        return Int(total / 60)
    }

    private var mostRecentTemplate: WorkoutTemplate? {
        guard let name = sessions.first?.templateName else { return templates.first }
        return templates.first { $0.name == name } ?? templates.first
    }

    private var mergedRecentActivity: [RecentActivityItem] {
        let strengthItems = sessions.map { RecentActivityItem.strength($0) }
        let cardioItems = health.recentWorkouts.map { RecentActivityItem.cardio($0) }
        return (strengthItems + cardioItems)
            .sorted { $0.date > $1.date }
    }
}

// MARK: - Card 1: Start

private struct StartCard: View {
    let template: WorkoutTemplate?
    let hasAnyTemplate: Bool
    let lastDoneDate: Date?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer()

                Circle()
                    .fill(.white)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.training)
                    )
            }
            .heroCardStyle(pillar: .trainingFill)
        }
        .buttonStyle(.plain)
    }

    private var title: String {
        guard let template else { return "Start a workout" }
        return "Start \(template.name)"
    }

    private var subtitle: String {
        guard let template else {
            return hasAnyTemplate ? "Pick a template to begin." : "Build your first template to begin."
        }
        let sets = template.sortedEntries.reduce(0) { $0 + $1.sortedSetEntries.count }
        let base = "\(template.sortedEntries.count) exercises · \(sets) sets"
        guard let lastDoneDate else { return base }
        return "\(base) · last done \(lastDoneText(lastDoneDate))"
    }

    private func lastDoneText(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInYesterday(date) { return "yesterday" }
        if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return date.formatted(.dateTime.weekday(.wide))
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Card 2: Stat tiles

private struct StatTilesRow: View {
    let sessions: Int
    let goal: Int
    let cardioMinutes: Int
    let steps: Int

    var body: some View {
        HStack(spacing: 10) {
            StatTile(label: "Sessions", value: "\(sessions)", unit: goal > 0 ? "/ \(goal)" : nil)
            StatTile(label: "Cardio", value: "\(cardioMinutes)", unit: "min")
            StatTile(label: "Steps today", value: stepsValue, unit: nil)
        }
    }

    private var stepsValue: String {
        steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)"
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Color.inkTertiary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.cardNumeral)
                    .foregroundStyle(Color.ink)
                if let unit {
                    Text(unit)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(radius: 20)
    }
}

// MARK: - Card 3: Templates

private struct TemplatesCard: View {
    let templates: [WorkoutTemplate]
    let mostRecentTemplateID: PersistentIdentifier?
    let onStart: (WorkoutTemplate) -> Void
    let onEdit: (WorkoutTemplate) -> Void
    let onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TEMPLATES")
                    .sectionLabelStyle()
                Spacer()
                Button("New", action: onNew)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.training)
            }

            if templates.isEmpty {
                Text("Create a template to see it here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTertiary)
            } else {
                HStack(spacing: 10) {
                    ForEach(templates) { template in
                        TemplateTile(template: template, isActive: template.id == mostRecentTemplateID) {
                            onStart(template)
                        } onLongPress: {
                            onEdit(template)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct TemplateTile: View {
    let template: WorkoutTemplate
    let isActive: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    private var totalSets: Int {
        template.sortedEntries.reduce(0) { $0 + $1.sortedSetEntries.count }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: template.sortedEntries.first?.exercise?.muscleGroup.icon ?? "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? Color.training : Color.inkTertiary)
                Text(template.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text("\(template.sortedEntries.count) · \(totalSets) sets")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(isActive ? Color.training.opacity(0.05) : Color.clear))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isActive ? Color.training.opacity(0.25) : Color.ink.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onLongPressGesture(perform: onLongPress)
    }
}

// MARK: - Card 4: Recent

enum RecentActivityItem: Identifiable {
    case strength(WorkoutSession)
    case cardio(CardioWorkout)

    var id: String {
        switch self {
        case .strength(let s): return "s-\(s.id)"
        case .cardio(let c): return "c-\(c.id)"
        }
    }

    var date: Date {
        switch self {
        case .strength(let s): return s.date
        case .cardio(let c): return c.startDate
        }
    }
}

private struct RecentCard: View {
    let items: [RecentActivityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("RECENT")
                    .sectionLabelStyle()
                Spacer()
                NavigationLink("See all") {
                    WorkoutHistoryView()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.training)
            }
            .padding(.bottom, 8)

            if items.isEmpty {
                Text("No activity yet.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTertiary)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(items.prefix(2).enumerated()), id: \.element.id) { index, item in
                        RecentRow(item: item)
                        if index == 0 && items.count > 1 {
                            Divider().overlay(Color.hairline).padding(.leading, 50)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

private struct RecentRow: View {
    let item: RecentActivityItem

    var body: some View {
        switch item {
        case .strength(let session):
            NavigationLink {
                WorkoutSessionDetailView(session: session)
            } label: {
                row(
                    icon: "dumbbell.fill",
                    title: session.name,
                    detail: "\(relativeDate(session.date)) · \(session.durationMinutes) min",
                    value: "\(Int(session.totalVolume))",
                    unit: "lb moved"
                )
            }
            .buttonStyle(.plain)
        case .cardio(let workout):
            row(
                icon: workout.activityType.symbolName,
                title: workout.activityType.displayName,
                detail: "\(relativeDate(workout.startDate)) · \(workout.statsSummary ?? workout.sourceName)",
                value: "\(Int(workout.duration / 60))",
                unit: "min"
            )
        }
    }

    private func row(icon: String, title: String, detail: String, value: String, unit: String) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, color: .training, size: 38, shape: .roundedSquare(radius: 13))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Color.ink)
                Text(detail)
                    .font(.rowDetail)
                    .foregroundStyle(Color.inkTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Start Workout picker (browse all templates)

private struct StartWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let templates: [WorkoutTemplate]
    let onStart: (WorkoutTemplate) -> Void
    let onEdit: (WorkoutTemplate) -> Void
    let onCreateNew: () -> Void
    let onStartFresh: () -> Void
    let onRepeatWorkout: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            QuickStartRow(onStartFresh: onStartFresh, onRepeatWorkout: onRepeatWorkout)

                            ForEach(templates) { template in
                                TemplateCard(template: template) {
                                    onStart(template)
                                } onEdit: {
                                    onEdit(template)
                                }
                            }

                            NewTemplateTile(action: onCreateNew)
                                .padding(.top, 4)
                        }
                        .padding()
                    }
                }
            }
            .background(Color.paper)
            .navigationTitle("Start Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.trainingTint)
                    .frame(width: 96, height: 96)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.training)
            }

            VStack(spacing: 6) {
                Text("No templates yet")
                    .font(.title3.bold())
                Text("Build a template with your exercises and sets, then start it here anytime.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: onCreateNew) {
                Label("Create a Template", systemImage: "plus")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.training)
            .padding(.horizontal, 40)
            .padding(.top, 4)

            QuickStartRow(onStartFresh: onStartFresh, onRepeatWorkout: onRepeatWorkout)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

private struct QuickStartRow: View {
    let onStartFresh: () -> Void
    let onRepeatWorkout: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            quickStartButton(title: "Start Fresh", icon: "plus", action: onStartFresh)
            quickStartButton(title: "Repeat a Workout", icon: "arrow.counterclockwise", action: onRepeatWorkout)
        }
    }

    private func quickStartButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .foregroundStyle(Color.training)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.training.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

private struct TemplateCard: View {
    let template: WorkoutTemplate
    let onStart: () -> Void
    let onEdit: () -> Void

    private var muscleGroups: [MuscleGroup] {
        var seen = Set<MuscleGroup>()
        var ordered: [MuscleGroup] = []
        for entry in template.sortedEntries {
            guard let group = entry.exercise?.muscleGroup, !seen.contains(group) else { continue }
            seen.insert(group)
            ordered.append(group)
        }
        return ordered
    }

    private var totalSets: Int {
        template.sortedEntries.reduce(0) { $0 + $1.sortedSetEntries.count }
    }

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.trainingTint)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.training)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 5) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(Color.ink)

                    Text("\(template.sortedEntries.count) exercise\(template.sortedEntries.count == 1 ? "" : "s") · \(totalSets) sets")
                        .font(.caption)
                        .foregroundStyle(Color.inkTertiary)

                    if !muscleGroups.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(muscleGroups.prefix(4)) { group in
                                Image(systemName: group.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.training)
                                    .frame(width: 22, height: 22)
                                    .background(Color.trainingTint)
                                    .clipShape(Circle())
                            }
                            if muscleGroups.count > 4 {
                                Text("+\(muscleGroups.count - 4)")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.inkSecondary)
                            .frame(width: 30, height: 30)
                            .background(Color.fill)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.training)
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .cardStyle(radius: 20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Repeat a past workout

private struct RepeatWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let sessions: [WorkoutSession]
    let onRepeat: (WorkoutSession) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No Past Workouts", systemImage: "arrow.counterclockwise", description: Text("Finish a workout and it'll show up here to repeat."))
                } else {
                    List(sessions) { session in
                        Button {
                            onRepeat(session)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Color.ink)
                                    Text("\(session.date.formatted(date: .abbreviated, time: .omitted)) · \(session.exerciseCount) exercise\(session.exerciseCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundStyle(Color.inkTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                    }
                }
            }
            .background(Color.paper)
            .navigationTitle("Repeat a Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct NewTemplateTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("New Template")
                    .font(.subheadline.bold())
            }
            .foregroundStyle(Color.training)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.training.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }
}
