import Foundation
import SwiftData

@Model
final class WorkoutGoals {
    var weeklyStrengthGoal: Int = 3
    var weeklyCardioGoal: Int = 2
    var dailyStepGoal: Int = 10000
    var weeklyStepGoal: Int = 70000
    var updatedAt: Date = Date()

    init(weeklyStrengthGoal: Int = 3, weeklyCardioGoal: Int = 2, dailyStepGoal: Int = 10000, weeklyStepGoal: Int = 70000) {
        self.weeklyStrengthGoal = weeklyStrengthGoal
        self.weeklyCardioGoal = weeklyCardioGoal
        self.dailyStepGoal = dailyStepGoal
        self.weeklyStepGoal = weeklyStepGoal
    }
}
