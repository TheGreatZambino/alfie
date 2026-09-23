import Foundation
import SwiftData

enum TrackingType: String, Codable, CaseIterable, Identifiable {
    case reps
    case time

    var id: Self { self }

    var label: String {
        switch self {
        case .reps: return "Sets"
        case .time: return "Time"
        }
    }
}

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
    var order: Int = 0
    var template: WorkoutTemplate?
    var trackingTypeRaw: String = TrackingType.reps.rawValue

    @Relationship(deleteRule: .cascade, inverse: \TemplateSetEntry.templateExercise)
    var setEntries: [TemplateSetEntry]? = []

    init(exercise: Exercise?, order: Int = 0, trackingType: TrackingType = .reps) {
        self.exercise = exercise
        self.order = order
        self.trackingTypeRaw = trackingType.rawValue
    }

    var trackingType: TrackingType {
        get { TrackingType(rawValue: trackingTypeRaw) ?? .reps }
        set { trackingTypeRaw = newValue.rawValue }
    }

    var sortedSetEntries: [TemplateSetEntry] {
        (setEntries ?? []).sorted { $0.setNumber < $1.setNumber }
    }
}

@Model
final class TemplateSetEntry {
    var setNumber: Int = 1
    var targetReps: Int = 10
    var targetWeight: Double = 0
    var targetDurationSeconds: Int = 0
    var templateExercise: TemplateExerciseEntry?

    init(setNumber: Int = 1, targetReps: Int = 10, targetWeight: Double = 0, targetDurationSeconds: Int = 0) {
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetDurationSeconds = targetDurationSeconds
    }
}
