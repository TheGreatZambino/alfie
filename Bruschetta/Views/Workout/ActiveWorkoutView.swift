import SwiftUI
import SwiftData
import Combine

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
    var currentSetIndex: Int? { sets.firstIndex { !$0.isLogged } }
}

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate

    @State private var startTime = Date()
    @State private var now = Date()
    @State private var draftEntries: [LoggedDraftEntry]
    @State private var showDiscardConfirm = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(template: WorkoutTemplate) {
        self.template = template
        _draftEntries = State(initialValue: template.sortedEntries.compactMap { entry in
            guard let exercise = entry.exercise else { return nil }
            let sets = entry.sortedSetEntries.map { LoggedDraftSet(reps: $0.targetReps, weight: $0.targetWeight) }
            return LoggedDraftEntry(exercise: exercise, sets: sets.isEmpty ? [LoggedDraftSet(reps: 10, weight: 0)] : sets)
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
            ScrollView {
                VStack(spacing: 14) {
                    if let currentExerciseIndex {
                        CurrentExerciseCard(
                            entry: $draftEntries[currentExerciseIndex],
                            lastTime: lastLoggedSet(for: draftEntries[currentExerciseIndex].exercise)
                        )

                        UpNextSection(entries: Array(draftEntries[(currentExerciseIndex + 1)...]))
                    } else {
                        AllSetsLoggedCard()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .tint(.training)
            .safeAreaInset(edge: .top, spacing: 0) {
                header
            }
            .confirmationDialog("Discard this workout?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard Workout", role: .destructive) { dismiss() }
                Button("Keep Going", role: .cancel) {}
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
                Text(template.name)
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
        .background(Color.trainingFill)
    }

    /// Most recent logged set for this exercise from prior sessions, for the "Last time" reference.
    private func lastLoggedSet(for exercise: Exercise) -> LoggedSet? {
        exercise.loggedSets?
            .filter { $0.session != nil }
            .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }
            .first
    }

    private func finish() {
        let session = WorkoutSession(date: startTime, name: template.name, templateName: template.name, durationSeconds: elapsed)
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

// MARK: - Current exercise (single set focus)

private struct CurrentExerciseCard: View {
    @Binding var entry: LoggedDraftEntry
    let lastTime: LoggedSet?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NOW")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.training)
                        .textCase(.uppercase)
                        .tracking(0.6)
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

            if entry.sets.contains(where: \.isLogged) {
                VStack(spacing: 8) {
                    ForEach(entry.sets.indices.filter { entry.sets[$0].isLogged }, id: \.self) { index in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.training)
                                .frame(width: 24, height: 24)
                                .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                            Text("Set \(index + 1)")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.inkTertiary)
                            Spacer()
                            Text("\(Int(entry.sets[index].weight)) lb × \(entry.sets[index].reps)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.inkTertiary)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.fill))
                    }
                }
            }

            if let currentIndex = entry.currentSetIndex {
                ActiveSetPanel(setNumber: currentIndex + 1, set: $entry.sets[currentIndex], target: lastTime) {
                    entry.sets[currentIndex].isLogged = true
                }
            }
        }
        .padding(18)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.training.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.ink.opacity(0.06), radius: 12, y: 10)
    }
}

private struct ActiveSetPanel: View {
    let setNumber: Int
    @Binding var set: LoggedDraftSet
    let target: LoggedSet?
    let onLog: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Set \(setNumber)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.training)
                Spacer()
                if let target {
                    Text("target \(Int(target.weight)) × \(target.reps)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkTertiary)
                }
            }

            HStack(spacing: 0) {
                stepperGroup(label: "WEIGHT") {
                    Stepper(value: $set.weight, in: 0...999, step: 5) {
                        Text("\(Int(set.weight))")
                            .font(.cardNumeral)
                            .foregroundStyle(Color.ink)
                            .frame(minWidth: 44)
                    }
                }

                Rectangle()
                    .fill(Color.ink.opacity(0.08))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                stepperGroup(label: "REPS") {
                    Stepper(value: $set.reps, in: 1...50) {
                        Text("\(set.reps)")
                            .font(.cardNumeral)
                            .foregroundStyle(Color.ink)
                            .frame(minWidth: 30)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.training, lineWidth: 1.5))

            Button(action: onLog) {
                Text("Log set \(setNumber)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.trainingFill)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.training, lineWidth: 1.5))
    }

    private func stepperGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.inkTertiary)
            content()
                .labelsHidden()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Up next

private struct UpNextSection: View {
    let entries: [LoggedDraftEntry]

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("UP NEXT")
                    .sectionLabelStyle()

                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.exercise.name)
                                .font(.rowTitle)
                                .foregroundStyle(Color.ink)
                            Spacer()
                            Text("\(entry.sets.count) sets")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkTertiary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.cardBorder, lineWidth: 1))
                    }
                }
            }
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
