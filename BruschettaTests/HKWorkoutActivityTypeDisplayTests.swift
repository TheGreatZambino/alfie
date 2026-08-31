import Testing
import HealthKit
@testable import Bruschetta

struct HKWorkoutActivityTypeDisplayTests {
    @Test(arguments: [
        (HKWorkoutActivityType.running, "Run"),
        (.cycling, "Ride"),
        (.walking, "Walk"),
        (.swimming, "Swim"),
        (.hiking, "Hike"),
        (.rowing, "Row"),
        (.elliptical, "Elliptical"),
        (.functionalStrengthTraining, "Strength"),
        (.traditionalStrengthTraining, "Strength"),
        (.yoga, "Yoga"),
        (.highIntensityIntervalTraining, "HIIT"),
        (.coreTraining, "Core"),
        (.stairClimbing, "Stair Climb")
    ])
    func displayNameMatchesKnownActivityTypes(type: HKWorkoutActivityType, expected: String) {
        #expect(type.displayName == expected)
    }

    @Test
    func displayNameFallsBackToWorkoutForUnmappedTypes() {
        #expect(HKWorkoutActivityType.archery.displayName == "Workout")
    }

    @Test
    func symbolNameFallsBackForUnmappedTypes() {
        #expect(HKWorkoutActivityType.archery.symbolName == "figure.mixed.cardio")
    }

    @Test
    func symbolNameIsNonEmptyForEveryMappedType() {
        let mapped: [HKWorkoutActivityType] = [
            .running, .cycling, .walking, .swimming, .hiking, .rowing, .elliptical,
            .functionalStrengthTraining, .traditionalStrengthTraining, .yoga,
            .highIntensityIntervalTraining, .coreTraining, .stairClimbing
        ]
        for type in mapped {
            #expect(!type.symbolName.isEmpty)
        }
    }
}
