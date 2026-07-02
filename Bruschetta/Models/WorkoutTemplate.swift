import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    var name: String = ""
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \TemplateExerciseEntry.template)
    var entries: [TemplateExerciseEntry]? = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }

    var sortedEntries: [TemplateExerciseEntry] {
        (entries ?? []).sorted { $0.order < $1.order }
    }
}

@Model
final class TemplateExerciseEntry {
    var exercise: Exercise?
    var targetSets: Int = 3
    var targetReps: Int = 10
    var order: Int = 0
    var template: WorkoutTemplate?

    init(exercise: Exercise?, targetSets: Int = 3, targetReps: Int = 10, order: Int = 0) {
        self.exercise = exercise
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.order = order
    }
}
