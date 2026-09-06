import SwiftUI
import SwiftData
import Combine

/// A workout to run, decoupled from persisted `WorkoutTemplate`s so a workout can also be
/// started fresh (no exercises yet) or repeated from a prior session.
struct WorkoutPlan: Identifiable {
    let id = UUID()
    var name: String
    var templateName: String?
    var entries: [WorkoutPlanEntry]

    static func template(_ template: WorkoutTemplate) -> WorkoutPlan {
        let entries: [WorkoutPlanEntry] = template.sortedEntries.compactMap { entry in
            guard let exercise = entry.exercise else { return nil }
            let sets = entry.sortedSetEntries.map { WorkoutPlanSet(reps: $0.targetReps, weight: $0.targetWeight) }
            return WorkoutPlanEntry(exercise: exercise, sets: sets.isEmpty ? [WorkoutPlanSet(reps: 10, weight: 0)] : sets)
        }
        return WorkoutPlan(name: template.name, templateName: template.name, entries: entries)
    }

    static func fresh() -> WorkoutPlan {
        WorkoutPlan(name: "Workout", templateName: nil, entries: [])
    }

    static func repeating(_ session: WorkoutSession) -> WorkoutPlan {
        var order: [Exercise] = []
        var setsByExercise: [PersistentIdentifier: [WorkoutPlanSet]] = [:]
        for loggedSet in (session.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
            guard let exercise = loggedSet.exercise else { continue }
            if setsByExercise[exercise.id] == nil {
                order.append(exercise)
                setsByExercise[exercise.id] = []
            }
            setsByExercise[exercise.id]?.append(WorkoutPlanSet(reps: loggedSet.reps, weight: loggedSet.weight))
        }
        let entries = order.map { exercise in
            WorkoutPlanEntry(exercise: exercise, sets: setsByExercise[exercise.id] ?? [WorkoutPlanSet(reps: 10, weight: 0)])
        }
        return WorkoutPlan(name: session.name, templateName: nil, entries: entries)
    }
}

struct WorkoutPlanEntry: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var sets: [WorkoutPlanSet]
}

struct WorkoutPlanSet {
    var reps: Int
    var weight: Double
}

private struct LoggedDraftSet: Identifiable {
    let id = UUID()
    var reps: Int
    var weight: Double
    var isLogged: Bool = false
}

private struct LoggedDraftEntry: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var sets: [LoggedDraftSet]

    var isComplete: Bool { sets.allSatisfy(\.isLogged) }
}

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let plan: WorkoutPlan

    @State private var startTime = Date()
    @State private var now = Date()
    @State private var draftEntries: [LoggedDraftEntry]
    @State private var showDiscardConfirm = false
    @State private var showExercisePicker = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(plan: WorkoutPlan) {
        self.plan = plan
        _draftEntries = State(initialValue: plan.entries.map { entry in
            LoggedDraftEntry(exercise: entry.exercise, sets: entry.sets.map { LoggedDraftSet(reps: $0.reps, weight: $0.weight) })
        })
    }

    private var elapsed: TimeInterval {
        now.timeIntervalSince(startTime)
    }

    private var elapsedText: String {
        let total = Int(elapsed)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var totalSets: Int { draftEntries.reduce(0) { $0 + $1.sets.count } }
    private var completedSets: Int { draftEntries.reduce(0) { $0 + $1.sets.filter(\.isLogged).count } }

    /// Index of the exercise currently in focus — the first one with an unlogged set.
    private var currentExerciseIndex: Int? {
        draftEntries.firstIndex { !$0.isComplete }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 14) {
                        if draftEntries.isEmpty {
                            EmptyPlanCard { showExercisePicker = true }
                        } else {
                            ForEach(draftEntries.indices, id: \.self) { index in
                                ExerciseCard(
                                    entry: $draftEntries[index],
                                    isFocused: index == currentExerciseIndex,
                                    lastTime: lastLoggedSet(for: draftEntries[index].exercise)
                                )
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
                .background(Color.paper)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(.training)
            .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(alreadySelected: Set(draftEntries.map(\.exercise.id))) { exercise in
                    draftEntries.append(LoggedDraftEntry(exercise: exercise, sets: [LoggedDraftSet(reps: 10, weight: 0)]))
                }
            }
            .onReceive(timer) { value in
                now = value
            }
            .interactiveDismissDisabled()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(plan.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button {
                    showDiscardConfirm = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(.white.opacity(0.18)))
                }

                Button("Finish") { finish() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .opacity(totalSets > 0 ? 1 : 0.5)
                    .disabled(totalSets == 0)
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(elapsedText)
                    .font(.heroNumeralScreen)
                    .monospacedDigit()
                    .foregroundStyle(.white)
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

    /// Most recent logged set for this exercise from prior sessions, for the "Last time" reference.
    private func lastLoggedSet(for exercise: Exercise) -> LoggedSet? {
        exercise.loggedSets?
            .filter { $0.session != nil }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }

    private func finish() {
        let session = WorkoutSession(date: startTime, name: plan.name, templateName: plan.templateName, durationSeconds: elapsed)
        modelContext.insert(session)

        for entry in draftEntries {
            for (index, draftSet) in entry.sets.enumerated() {
                let loggedSet = LoggedSet(exercise: entry.exercise, setNumber: index + 1, weight: draftSet.weight, reps: draftSet.reps)
                loggedSet.session = session
                modelContext.insert(loggedSet)
            }
        }
        try? modelContext.save()
        AnalyticsService.workoutLogged(.strength)
        dismiss()
    }
}

// MARK: - Exercise card (every movement fully expanded, completable in any order)

private struct ExerciseCard: View {
    @Binding var entry: LoggedDraftEntry
    let isFocused: Bool
    let lastTime: LoggedSet?

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
                        Text("\(Int(lastTime.weight)) × \(lastTime.reps)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.ink)
                    }
                }
            }

            setsList

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
                ActiveSetRow(setNumber: index + 1, set: $entry.sets[index]) {
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
            entry.sets.append(LoggedDraftSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0))
        } label: {
            Label("Add Set", systemImage: "plus")
                .font(.caption.bold())
                .foregroundStyle(Color.training)
        }
        .buttonStyle(.plain)
    }
}

/// One editable set row: tap the leading circle to mark it logged, tap into
/// the weight/reps fields to type a value directly (auto-selected on focus).
private struct ActiveSetRow: View {
    let setNumber: Int
    @Binding var set: LoggedDraftSet
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            logToggle

            Text("\(setNumber)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkTertiary)
                .frame(minWidth: 16, alignment: .leading)

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
            }
            .buttonStyle(.plain)
        }
    }

    private var logToggle: some View {
        Button {
            set.isLogged.toggle()
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
        }
        .buttonStyle(.plain)
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
