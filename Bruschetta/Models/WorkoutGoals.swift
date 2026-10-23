import Foundation
import SwiftData

@Model
final class WorkoutGoals {
    var weeklyStrengthGoal: Int = 3
    var weeklyCardioGoal: Int = 2
    var dailyStepGoal: Int = 10000
    var weeklyStepGoal: Int = 70000
    var weeklyMileGoal: Double = 0
    var monthlyMileGoal: Double = 0
    var averageDailyMileGoal: Double = 0
    var updatedAt: Date = Date()

    init(weeklyStrengthGoal: Int = 3, weeklyCardioGoal: Int = 2, dailyStepGoal: Int = 10000, weeklyStepGoal: Int = 70000, weeklyMileGoal: Double = 0, monthlyMileGoal: Double = 0, averageDailyMileGoal: Double = 0) {
        self.weeklyStrengthGoal = weeklyStrengthGoal
        self.weeklyCardioGoal = weeklyCardioGoal
        self.dailyStepGoal = dailyStepGoal
        self.weeklyStepGoal = weeklyStepGoal
        self.weeklyMileGoal = weeklyMileGoal
        self.monthlyMileGoal = monthlyMileGoal
        self.averageDailyMileGoal = averageDailyMileGoal
    }
}
