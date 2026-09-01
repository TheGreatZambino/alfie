import AppIntents

/// Lets Siri resolve "breakfast" / "lunch" / "dinner" / "snack" as a typed parameter
/// without teaching `MealType` itself about App Intents.
extension MealType: AppEnum {
    nonisolated(unsafe) static var typeDisplayRepresentation: TypeDisplayRepresentation = "Meal"

    nonisolated(unsafe) static var caseDisplayRepresentations: [MealType: DisplayRepresentation] = [
        .breakfast: DisplayRepresentation(title: "Breakfast"),
        .lunch: DisplayRepresentation(title: "Lunch"),
        .dinner: DisplayRepresentation(title: "Dinner"),
        .snack: DisplayRepresentation(title: "Snack")
    ]
}
