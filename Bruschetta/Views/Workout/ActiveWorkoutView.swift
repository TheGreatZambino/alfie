import SwiftUI
import SwiftData
import Combine

/// A workout to run, decoupled from persisted `WorkoutTemplate`s so a workout can also be
/// started fresh (no exercises yet) or repeated from a prior session.
struct WorkoutPlan: Identifiable {
    let id = UUID()
    var name: String
    var templateName: String?
    /// The persisted template this plan was started from, if any.
    var templateID: PersistentIdentifier?
    var entries: [WorkoutPlanEntry]

    static func template(_ template: WorkoutTemplate) -> WorkoutPlan {
        let entries: [WorkoutPlanEntry] = template.sortedEntries.compactMap { entry in
            guard let exercise = entry.exercise else { return nil }
            let sets = entry.sortedSetEntries.map { WorkoutPlanSet(reps: $0.targetReps, weight: $0.targetWeight, durationSeconds: $0.targetDurationSeconds, restSeconds: $0.restSeconds) }
            return WorkoutPlanEntry(exercise: exercise, trackingType: entry.trackingType, sets: sets.isEmpty ? [WorkoutPlanSet(reps: 10, weight: 0)] : sets)
        }
        return WorkoutPlan(name: template.name, templateName: template.name, templateID: template.persistentModelID, entries: entries)
    }

    static func fresh() -> WorkoutPlan {
        WorkoutPlan(name: "Workout", templateName: nil, templateID: nil, entries: [])
    }

    static func repeating(_ session: WorkoutSession) -> WorkoutPlan {
        var order: [Exercise] = []
        var setsByExercise: [PersistentIdentifier: [WorkoutPlanSet]] = [:]
        var trackingByExercise: [PersistentIdentifier: TrackingType] = [:]
        for loggedSet in (session.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
            guard let exercise = loggedSet.exercise else { continue }
            if setsByExercise[exercise.id] == nil {
                order.append(exercise)
                setsByExercise[exercise.id] = []
                trackingByExercise[exercise.id] = loggedSet.trackingType
            }
            setsByExercise[exercise.id]?.append(WorkoutPlanSet(reps: loggedSet.reps, weight: loggedSet.weight, durationSeconds: loggedSet.durationSeconds))
        }
        let entries = order.map { exercise in
            WorkoutPlanEntry(exercise: exercise, trackingType: trackingByExercise[exercise.id] ?? .reps, sets: setsByExercise[exercise.id] ?? [WorkoutPlanSet(reps: 10, weight: 0)])
        }
        return WorkoutPlan(name: session.name, templateName: nil, templateID: nil, entries: entries)
    }
}

struct WorkoutPlanEntry: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var trackingType: TrackingType = .reps
    var sets: [WorkoutPlanSet]
}

struct WorkoutPlanSet {
    var reps: Int
    var weight: Double
    var durationSeconds: Int = 0
    var restSeconds: Int = 0
}


struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var session = ActiveWorkoutSession.shared

    @State private var showDiscardConfirm = false
    @State private var showExercisePicker = false
    @State private var showUpdateTemplateConfirm = false
    @State private var entryPendingRemoval: UUID?
    @State private var isReordering = false
    @State private var bulkRestTarget: RestBulkTarget?

    private var plan: WorkoutPlan? { session.plan }
    private var draftEntries: [LoggedDraftEntry] { session.draftEntries }
    private var totalSets: Int { session.totalSets }
    private var completedSets: Int { session.completedSets }
    private var currentExerciseIndex: Int? { session.currentExerciseIndex }

    private func elapsedText(at date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(session.startTime)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if let restEndDate = session.restEndDate {
                    RestCountdownBanner(endDate: restEndDate, total: session.restTotal) { delta in
                        session.adjustRest(by: delta)
                    } onSkip: {
                        session.skipRest()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if isReordering {
                    ReorderExerciseList(items: draftEntries.map {
                        ReorderRowItem(id: $0.id, title: $0.exercise.name, subtitle: "\($0.sets.count) \($0.sets.count == 1 ? "set" : "sets")")
                    }) { source, destination in
                        withAnimation(.snappy) { session.draftEntries.move(fromOffsets: source, toOffset: destination) }
                    }
                } else {
                ScrollView {
                    VStack(spacing: 14) {
                        if draftEntries.isEmpty {
                            EmptyPlanCard { showExercisePicker = true }
                        } else {
                            ForEach(draftEntries.map(\.id), id: \.self) { entryID in
                              if let index = draftEntries.firstIndex(where: { $0.id == entryID }) {
                                ExerciseCard(
                                    entry: $session.draftEntries[index],
                                    isFocused: index == currentExerciseIndex,
                                    lastTime: lastLoggedSet(for: draftEntries[index].exercise),
                                    onSetLogged: startRest,
                                    onBulkRest: {
                                        let entry = draftEntries[index]
                                        bulkRestTarget = RestBulkTarget(entryID: entry.id, title: entry.exercise.name, initialSeconds: entry.sets.first { $0.restSeconds > 0 }?.restSeconds ?? 0)
                                    },
                                    onRemove: { entryPendingRemoval = draftEntries[index].id }
                                )
                              }
                            }

                            if currentExerciseIndex == nil {
                                AllSetsLoggedCard()
                            }

                            AddExerciseTile { showExercisePicker = true }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color.paper)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(.training)
            .confirmationDialog("Are you sure you want to discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) { session.discard() }
                Button("Keep Going", role: .cancel) {}
            }
            .confirmationDialog("Update \"\(plan?.templateName ?? "template")\"?", isPresented: $showUpdateTemplateConfirm, titleVisibility: .visible) {
                Button("Overwrite Template") { session.finish(context: modelContext, updateTemplate: true) }
                Button("Keep Original Template") { session.finish(context: modelContext) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You changed this workout. Save the changes to the template for next time?")
            }
            .confirmationDialog(
                "Remove \(draftEntries.first { $0.id == entryPendingRemoval }?.exercise.name ?? "exercise")?",
                isPresented: Binding(get: { entryPendingRemoval != nil }, set: { if !$0 { entryPendingRemoval = nil } }),
                titleVisibility: .visible
            ) {
                Button("Remove Exercise", role: .destructive) {
                    if let id = entryPendingRemoval { removeEntry(id) }
                    entryPendingRemoval = nil
                }
                Button("Cancel", role: .cancel) { entryPendingRemoval = nil }
            } message: {
                Text("This removes the exercise and all of its sets from this workout.")
            }
            .sheet(item: $bulkRestTarget) { target in
                BulkRestSheet(target: target) { seconds in
                    for index in session.draftEntries.indices where target.entryID == nil || session.draftEntries[index].id == target.entryID {
                        for setIndex in session.draftEntries[index].sets.indices {
                            session.draftEntries[index].sets[setIndex].restSeconds = seconds
                        }
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(alreadySelected: Set(draftEntries.map(\.exercise.id))) { exercise in
                    session.draftEntries.append(LoggedDraftEntry(exercise: exercise, sets: [LoggedDraftSet(reps: 10, weight: 0)]))
                }
            }
            .onChange(of: session.liveActivityState) { _, _ in
                session.syncLiveActivity()
            }
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan?.name ?? "Workout")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button {
                    session.minimize()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.18)))
                        .tapTarget(layoutWidth: 36, layoutHeight: 28)
                }
                .accessibilityLabel("Minimize workout")

                Button {
                    withAnimation(.snappy) { isReordering.toggle() }
                } label: {
                    Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isReordering ? Color.training : .white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(isReordering ? Color.white : .white.opacity(0.18)))
                        .tapTarget(layoutWidth: 36, layoutHeight: 28)
                }
                .opacity(draftEntries.count > 1 ? 1 : 0.5)
                .disabled(draftEntries.count < 2)
                .accessibilityLabel(isReordering ? "Done reordering" : "Reorder exercises")

                Button {
                    bulkRestTarget = RestBulkTarget(entryID: nil, title: "Rest for Whole Workout", initialSeconds: draftEntries.flatMap(\.sets).first { $0.restSeconds > 0 }?.restSeconds ?? 0)
                } label: {
                    Image(systemName: "timer")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.18)))
                        .tapTarget(layoutWidth: 36, layoutHeight: 28)
                }
                .opacity(totalSets > 0 ? 1 : 0.5)
                .disabled(totalSets == 0)
                .accessibilityLabel("Set rest for all exercises")

                Button {
                    showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.18)))
                        .tapTarget(layoutWidth: 36, layoutHeight: 28)
                }

                Button("Finish") {
                    if session.planDiffersFromTemplate {
                        showUpdateTemplateConfirm = true
                    } else {
                        session.finish(context: modelContext)
                    }
                }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .opacity(totalSets > 0 ? 1 : 0.5)
                    .disabled(totalSets == 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(at: context.date))
                        .font(.heroNumeralScreen)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                Text("\(completedSets) of \(totalSets) sets")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
            }

            SegmentedBar(
                segments: [.init(fraction: totalSets > 0 ? Double(completedSets) / Double(totalSets) : 0, color: .white)],
                trackColor: .white.opacity(0.25),
                height: 6
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(Color.trainingFill.ignoresSafeArea(edges: .top))
    }

    private func removeEntry(_ id: UUID) {
        withAnimation(.snappy) {
            session.draftEntries.removeAll { $0.id == id }
        }
    }

    private func startRest(_ seconds: Int) {
        session.startRest(seconds)
    }

    /// Most recent logged set for this exercise from prior sessions, for the "Last time" reference.
    private func lastLoggedSet(for exercise: Exercise) -> LoggedSet? {
        exercise.loggedSets?
            .filter { $0.session != nil }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }
}


// MARK: - Exercise card (every movement fully expanded, completable in any order)

private struct ExerciseCard: View {
    @Binding var entry: LoggedDraftEntry
    let isFocused: Bool
    let lastTime: LoggedSet?
    let onSetLogged: (Int) -> Void
    let onBulkRest: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if isFocused {
                        Text("NOW")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.training)
                            .textCase(.uppercase)
                            .tracking(0.6)
                    }
                    Text(entry.exercise.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.ink)
                }

                Spacer()

                if let lastTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Last time")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkTertiary)
                        Text(lastTimeText(lastTime))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.ink)
                    }
                }

                Menu {
                    Button(action: onBulkRest) {
                        Label("Set Rest for All Sets", systemImage: "timer")
                    }
                    Button(role: .destructive, action: onRemove) {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.fill)
                        .clipShape(Circle())
                        .tapTarget(layoutWidth: 30, layoutHeight: 30)
                }
            }

            Picker("Tracking", selection: $entry.trackingType) {
                ForEach(TrackingType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)

            setsList

            if entry.sets.contains(where: { $0.restSeconds > 0 }) {
                RestSoundNote()
            }

            addSetButton
        }
        .padding(18)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(isFocused ? Color.training.opacity(0.25) : Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.ink.opacity(0.06), radius: isFocused ? 12 : 4, y: isFocused ? 10 : 3)
    }

    private var setsList: some View {
        VStack(spacing: 8) {
            ForEach(entry.sets.indices, id: \.self) { index in
                ActiveSetRow(setNumber: index + 1, trackingType: entry.trackingType, set: $entry.sets[index], onLogged: onSetLogged) {
                    _ = withAnimation(.snappy) {
                        entry.sets.remove(at: index)
                    }
                }
            }
        }
    }

    private var addSetButton: some View {
        Button {
            let last = entry.sets.last
            entry.sets.append(LoggedDraftSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0, durationSeconds: last?.durationSeconds ?? 30, restSeconds: last?.restSeconds ?? 0))
        } label: {
            Label("Add Set", systemImage: "plus")
                .font(.caption.bold())
                .foregroundStyle(Color.training)
        }
        .buttonStyle(.plain)
    }

    private func lastTimeText(_ set: LoggedSet) -> String {
        if set.trackingType == .time {
            return durationLabel(set.durationSeconds)
        }
        return "\(Int(set.weight)) × \(set.reps)"
    }
}


/// One editable set row: tap the leading circle to mark it logged, tap into
/// the weight/reps fields to type a value directly (auto-selected on focus).
private struct ActiveSetRow: View {
    let setNumber: Int
    let trackingType: TrackingType
    @Binding var set: LoggedDraftSet
    let onLogged: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            setFields
            RestTimerRow(seconds: $set.restSeconds)
        }
    }

    private var setFields: some View {
        HStack(spacing: 8) {
            logToggle

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkTertiary)
                .frame(minWidth: 16, alignment: .leading)

            if trackingType == .reps {
                HStack(spacing: 4) {
                    SelectAllIntTextField(value: $set.reps)
                        .frame(width: 32)
                    Text("reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                HStack(spacing: 4) {
                    DurationField(totalSeconds: $set.durationSeconds)
                    Text("min:sec")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.fill)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 4) {
                SelectAllTextField(value: $set.weight)
                    .frame(width: 52)
                Text("lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer(minLength: 0)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .tapTarget(layoutWidth: 24, layoutHeight: 24)
            }
            .buttonStyle(.plain)
        }
    }

    private var logToggle: some View {
        Button {
            set.isLogged.toggle()
            if set.isLogged { onLogged(set.restSeconds) }
        } label: {
            ZStack {
                Circle()
                    .fill(set.isLogged ? Color.training : Color.clear)
                Circle()
                    .strokeBorder(Color.training, lineWidth: 1.5)
                if set.isLogged {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            // Grow the tap target to 44pt without changing the row's layout.
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(-9)
        }
        .buttonStyle(.plain)
    }
}

/// Countdown shown while resting between sets; tap -15/+15 to adjust or skip.
private struct RestCountdownBanner: View {
    let endDate: Date
    let total: TimeInterval
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let left = max(0, endDate.timeIntervalSince(context.date))
            let remaining = Int(ceil(left))
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(Color.training)
                    Text("Rest")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                    Text(RestTimerRow.label(remaining))
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.training)
                    Spacer()
                    Button("-15") { onAdjust(-RestTimerRow.step) }
                    Button("+15") { onAdjust(RestTimerRow.step) }
                    Button("Skip", action: onSkip)
                }
                ProgressView(value: total > 0 ? min(1, left / total) : 0)
                    .tint(.training)
            }
            .font(.subheadline.weight(.semibold))
            .tint(.training)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.training.opacity(0.12))
        }
    }
}

private struct AllSetsLoggedCard: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.training)
            Text("All sets logged")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ink)
            Text("Tap Finish to save this workout.")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct EmptyPlanCard: View {
    let onAddExercise: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Color.training)
            Text("Add your first exercise")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.ink)
            Text("Build this workout as you go.")
                .font(.system(size: 14))
                .foregroundStyle(Color.inkTertiary)

            Button(action: onAddExercise) {
                Label("Add Exercise", systemImage: "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.trainingFill)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

private struct AddExerciseTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Add Exercise")
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
