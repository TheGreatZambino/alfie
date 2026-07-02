import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var date: Date = Date()
    var name: String = ""
    var templateName: String?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet]? = []

    init(date: Date = Date(), name: String, templateName: String? = nil) {
        self.date = date
        self.name = name
        self.templateName = templateName
    }

    var totalVolume: Double {
        (sets ?? []).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var exerciseCount: Int {
        Set((sets ?? []).compactMap { $0.exercise?.name }).count
    }
}

@Model
final class LoggedSet {
    var exercise: Exercise?
    var setNumber: Int = 1
    var weight: Double = 0
    var reps: Int = 0
    var isWarmup: Bool = false
    var session: WorkoutSession?

    init(exercise: Exercise?, setNumber: Int = 1, weight: Double = 0, reps: Int = 0, isWarmup: Bool = false) {
        self.exercise = exercise
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.isWarmup = isWarmup
    }
}
