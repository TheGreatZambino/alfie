import SwiftUI
import SwiftData

private struct DraftEntry: Identifiable {
    static let defaultSets = [DraftSet(), DraftSet(), DraftSet()]

    let id = UUID()
    var exercise: Exercise
    var sets: [DraftSet] = defaultSets
}

private struct DraftSet: Identifiable {
    let id = UUID()
    var reps: Int = 10
    var weight: Double = 0
}

struct NewTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let existingTemplate: WorkoutTemplate?

    @State private var name: String
    @State private var draftEntries: [DraftEntry]
    @State private var showExercisePicker = false
    @State private var showDeleteConfirm = false

    init(template: WorkoutTemplate? = nil) {
        existingTemplate = template
        _name = State(initialValue: template?.name ?? "")
        _draftEntries = State(initialValue: (template?.sortedEntries ?? []).compactMap { entry in
            guard let exercise = entry.exercise else { return nil }
            let sets = entry.sortedSetEntries.map { DraftSet(reps: $0.targetReps, weight: $0.targetWeight) }
            return DraftEntry(exercise: exercise, sets: sets.isEmpty ? DraftEntry.defaultSets : sets)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    nameCard

                    if draftEntries.isEmpty {
                        emptyExercisesState
                    } else {
                        ForEach($draftEntries) { $entry in
                            ExerciseCard(entry: $entry) {
                                withAnimation(.snappy) {
                                    draftEntries.removeAll { $0.id == entry.id }
                                }
                            }
                        }

                        AddExerciseTile {
                            showExercisePicker = true
                        }
                    }

                    if existingTemplate != nil {
                        deleteTemplateButton
                    }
                }
                .padding()
            }
            .background(Color.paper)
            .navigationTitle(existingTemplate == nil ? "New Strength Template" : "Edit Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || draftEntries.isEmpty || draftEntries.contains { $0.sets.isEmpty })
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(alreadySelected: Set(draftEntries.map(\.exercise.id))) { exercise in
                    withAnimation(.snappy) {
                        draftEntries.append(DraftEntry(exercise: exercise))
                    }
                }
            }
            .confirmationDialog("Delete this template?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Template", role: .destructive) { deleteTemplate() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private var deleteTemplateButton: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            Label("Delete Template", systemImage: "trash")
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.red)
        .padding(.top, 4)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TEMPLATE NAME")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            TextField("e.g. Push Day", text: $name)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.words)
        }
        .cardStyle()
    }

    private var emptyExercisesState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.training.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.training)
            }

            VStack(spacing: 4) {
                Text("No exercises yet")
                    .font(.headline)
                Text("Add exercises and set your target reps and weight.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.training)
            .padding(.horizontal, 24)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardStyle()
    }

    private func save() {
        let template: WorkoutTemplate
        if let existingTemplate {
            existingTemplate.name = name
            for entry in existingTemplate.entries ?? [] {
                modelContext.delete(entry)
            }
            template = existingTemplate
        } else {
            template = WorkoutTemplate(name: name)
            modelContext.insert(template)
        }

        for (index, entry) in draftEntries.enumerated() {
            let templateEntry = TemplateExerciseEntry(exercise: entry.exercise, order: index)
            templateEntry.template = template
            modelContext.insert(templateEntry)

            for (setIndex, draftSet) in entry.sets.enumerated() {
                let setEntry = TemplateSetEntry(setNumber: setIndex + 1, targetReps: draftSet.reps, targetWeight: draftSet.weight)
                setEntry.templateExercise = templateEntry
                modelContext.insert(setEntry)
            }
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteTemplate() {
        guard let existingTemplate else { return }
        modelContext.delete(existingTemplate)
        try? modelContext.save()
        dismiss()
    }
}

private struct ExerciseCard: View {
    @Binding var entry: DraftEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(systemName: entry.exercise.muscleGroup.icon, color: .training, size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exercise.name)
                        .font(.headline)
                    Text(entry.exercise.muscleGroup.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        let last = entry.sets.last
                        entry.sets.append(DraftSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0))
                    } label: {
                        Label("Add Set", systemImage: "plus")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Remove Exercise", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 8) {
                ForEach(entry.sets.indices, id: \.self) { index in
                    SetRow(setNumber: index + 1, set: $entry.sets[index]) {
                        _ = withAnimation(.snappy) {
                            entry.sets.remove(at: index)
                        }
                    }
                }
            }

            Button {
                let last = entry.sets.last
                entry.sets.append(DraftSet(reps: last?.reps ?? 10, weight: last?.weight ?? 0))
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.caption.bold())
                    .foregroundStyle(Color.training)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }
}

private struct SetRow: View {
    let setNumber: Int
    @Binding var set: DraftSet
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(setNumber)")
                .font(.caption.bold())
                .foregroundStyle(Color.training)
                .frame(width: 24, height: 24)
                .background(Color.training.opacity(0.12))
                .clipShape(Circle())

            HStack(spacing: 4) {
                Stepper(value: $set.reps, in: 1...50) {
                    Text("\(set.reps)")
                        .font(.subheadline.bold())
                        .frame(minWidth: 22, alignment: .trailing)
                }
                .fixedSize()
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            HStack(spacing: 4) {
                SelectAllTextField(value: $set.weight)
                    .frame(width: 44)
                Text("lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
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

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let alreadySelected: Set<PersistentIdentifier>
    let onSelect: (Exercise) -> Void

    @State private var searchText = ""
    @State private var showAddCustom = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(MuscleGroup.allCases) { group in
                    let groupExercises = filtered.filter { $0.muscleGroup == group }
                    if !groupExercises.isEmpty {
                        Section(group.label) {
                            ForEach(groupExercises) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if alreadySelected.contains(exercise.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(Color.training)
                                        }
                                    }
                                }
                                .disabled(alreadySelected.contains(exercise.id))
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddCustom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCustom) {
                NewExerciseView { exercise in
                    onSelect(exercise)
                    dismiss()
                }
            }
        }
    }

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

struct NewExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let onCreate: (Exercise) -> Void

    @State private var name: String = ""
    @State private var muscleGroup: MuscleGroup = .other

    var body: some View {
        NavigationStack {
            Form {
                TextField("Exercise name", text: $name)
                Picker("Muscle Group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Text(group.label).tag(group)
                    }
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func save() {
        let exercise = Exercise(name: name, muscleGroup: muscleGroup, isCustom: true)
        modelContext.insert(exercise)
        try? modelContext.save()
        onCreate(exercise)
        dismiss()
    }
}
