import Foundation
import SwiftData

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, arms, legs, core, fullBody, other

    var id: Self { self }

    var label: String {
        switch self {
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .arms: return "Arms"
        case .legs: return "Legs"
        case .core: return "Core"
        case .fullBody: return "Full Body"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .shoulders: return "figure.arms.open"
        case .arms: return "dumbbell.fill"
        case .legs: return "figure.squat"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

@Model
final class Exercise {
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.other.rawValue
    var isCustom: Bool = false

    init(name: String, muscleGroup: MuscleGroup, isCustom: Bool = false) {
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.isCustom = isCustom
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
        set { muscleGroupRaw = newValue.rawValue }
    }

    static let starterExercises: [(name: String, muscleGroup: MuscleGroup)] = [
        ("Bench Press", .chest),
        ("Incline Dumbbell Press", .chest),
        ("Push-Up", .chest),
        ("Barbell Row", .back),
        ("Pull-Up", .back),
        ("Lat Pulldown", .back),
        ("Deadlift", .back),
        ("Overhead Press", .shoulders),
        ("Lateral Raise", .shoulders),
        ("Bicep Curl", .arms),
        ("Tricep Pushdown", .arms),
        ("Back Squat", .legs),
        ("Romanian Deadlift", .legs),
        ("Leg Press", .legs),
        ("Walking Lunge", .legs),
        ("Plank", .core),
        ("Hanging Leg Raise", .core)
    ]
}
