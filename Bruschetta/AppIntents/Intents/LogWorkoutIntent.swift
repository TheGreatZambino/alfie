import AppIntents
import SwiftData

/// Logs a quick, set-free workout session — good for a voice-first "I just worked out
/// for 45 minutes" flow. Set-by-set logging stays in-app via `ActiveWorkoutView`.
struct LogWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Workout"
    static var description = IntentDescription("Log a completed workout session in Alfie Track.")

    @Parameter(title: "Workout Name", default: "Workout")
    var name: String

    @Parameter(title: "Duration (minutes)")
    var durationMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$durationMinutes)-minute \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(AppModelContainer.shared)

        let session = WorkoutSession(date: .now, name: name, durationSeconds: TimeInterval(durationMinutes * 60))
        context.insert(session)
        try context.save()

        return .result(dialog: "Logged \(name) — \(durationMinutes) minutes.")
    }
}
