import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date = Date()
    var name: String = ""
    var templateName: String?
    var durationSeconds: TimeInterval = 0

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet]? = []

    init(date: Date = Date(), name: String, templateName: String? = nil, durationSeconds: TimeInterval = 0) {
        self.date = date
        self.name = name
        self.templateName = templateName
        self.durationSeconds = durationSeconds
    }

    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }

    var totalVolume: Double {
        (sets ?? []).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var exerciseCount: Int {
        Set((sets ?? []).compactMap { $0.exercise?.name }).count
    }

    var prCount: Int {
        (sets ?? []).filter(\.isPR).count
    }
}

@Model
final class LoggedSet {
    var exercise: Exercise?
    var setNumber: Int = 1
    var weight: Double = 0
    var reps: Int = 0
    var durationSeconds: Int = 0
    var trackingTypeRaw: String = TrackingType.reps.rawValue
    var isWarmup: Bool = false
    var isPR: Bool = false
    var session: WorkoutSession?

    init(exercise: Exercise?, setNumber: Int = 1, weight: Double = 0, reps: Int = 0, durationSeconds: Int = 0, trackingType: TrackingType = .reps, isWarmup: Bool = false) {
        self.exercise = exercise
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.trackingTypeRaw = trackingType.rawValue
        self.isWarmup = isWarmup
    }

    var trackingType: TrackingType {
        get { TrackingType(rawValue: trackingTypeRaw) ?? .reps }
        set { trackingTypeRaw = newValue.rawValue }
    }
}
