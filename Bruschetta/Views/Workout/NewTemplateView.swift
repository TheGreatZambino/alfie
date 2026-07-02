import SwiftUI
import SwiftData

struct NewTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var draftEntries: [DraftEntry] = []
    @State private var showExercisePicker = false

    private struct DraftEntry: Identifiable {
        let id = UUID()
        var exercise: Exercise
        var targetSets: Int = 3
        var targetReps: Int = 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $name)
                }

                Section("Exercises") {
                    ForEach($draftEntries) { $entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.exercise.name)
                                .font(.subheadline.bold())
                            Stepper("Sets: \(entry.targetSets)", value: $entry.targetSets, in: 1...10)
                            Stepper("Reps: \(entry.targetReps)", value: $entry.targetReps, in: 1...30)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        draftEntries.remove(atOffsets: offsets)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || draftEntries.isEmpty)
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(alreadySelected: Set(draftEntries.map(\.exercise.id))) { exercise in
                    draftEntries.append(DraftEntry(exercise: exercise))
                }
            }
        }
    }

    private func save() {
        let template = WorkoutTemplate(name: name)
        modelContext.insert(template)
        for (index, entry) in draftEntries.enumerated() {
            let templateEntry = TemplateExerciseEntry(
                exercise: entry.exercise,
                targetSets: entry.targetSets,
                targetReps: entry.targetReps,
                order: index
            )
            templateEntry.template = template
            modelContext.insert(templateEntry)
        }
        try? modelContext.save()
        dismiss()
    }
}

private struct ExercisePickerView: View {
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
                                                .foregroundStyle(Color.appAccent)
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

private struct NewExerciseView: View {
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
