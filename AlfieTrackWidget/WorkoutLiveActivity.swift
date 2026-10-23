import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    private static let accent = Color(red: 192.0 / 255, green: 94.0 / 255, blue: 69.0 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .padding(16)
                .activityBackgroundTint(Self.accent)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context)
                        .font(.title3.bold())
                        .frame(maxWidth: 90, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    controls(context.state, tint: Self.accent)
                }
            } compactLeading: {
                Text("\(context.state.completedSets)/\(context.state.totalSets)")
                    .font(.caption.bold())
                    .foregroundStyle(Self.accent)
            } compactTrailing: {
                timer(context)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Self.accent)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                timer(context)
                    .font(.title3.bold())
                    .frame(maxWidth: 100, alignment: .trailing)
            }
            controls(context.state, tint: .white)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func controls(_ state: WorkoutActivityAttributes.ContentState, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let exercise = state.currentExercise {
                HStack {
                    Text(exercise)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("Set \(state.setNumber) of \(state.setsInExercise) · \(state.effort)")
                        .font(.caption)
                        .opacity(0.85)
                }

                HStack(spacing: 10) {
                    stepper("minus", delta: -WorkoutLiveAction.weightStep)
                    Text("\(state.weight.formatted(.number.precision(.fractionLength(0...1)))) lb")
                        .font(.title2.bold())
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                    stepper("plus", delta: WorkoutLiveAction.weightStep)
                }

                HStack(spacing: 10) {
                    Button(intent: LogSetIntent()) {
                        Label("Log Set", systemImage: "checkmark")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .tint(tint)
                    Button(intent: NextExerciseIntent()) {
                        Label("Next Exercise", systemImage: "forward.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .tint(tint.opacity(0.6))
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("All sets logged — open the app to finish")
                    .font(.headline)
            }

            ProgressView(value: progress(state))
                .tint(tint)
            Text("\(state.completedSets) of \(state.totalSets) sets")
                .font(.caption)
                .opacity(0.85)
        }
    }

    private func stepper(_ symbol: String, delta: Double) -> some View {
        Button(intent: AdjustWeightIntent(delta: delta)) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .frame(width: 40, height: 28)
        }
        .buttonStyle(.bordered)
        .tint(.white)
    }

    private func timer(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        Text(timerInterval: context.attributes.startDate...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
    }

    private func progress(_ state: WorkoutActivityAttributes.ContentState) -> Double {
        state.totalSets > 0 ? Double(state.completedSets) / Double(state.totalSets) : 0
    }
}
