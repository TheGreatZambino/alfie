import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct WorkoutLiveActivity: Widget {
    private static let accent = Color(red: 192.0 / 255, green: 94.0 / 255, blue: 69.0 / 255)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreen(context)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
                    controls(context.state, tint: Self.accent, onTint: .white)
                }
            } compactLeading: {
                Text("\(context.state.completedSets)/\(context.state.totalSets)")
                    .font(.caption.bold())
                    .foregroundStyle(Self.accent)
            } compactTrailing: {
                if let end = context.state.restEndDate, end > Date() {
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 52)
                } else {
                    timer(context)
                        .frame(maxWidth: 52)
                }
            } minimal: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(Self.accent)
            }
        }
    }

    private func lockScreen(_ context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Spacer()
                timer(context)
                    .font(.title3.bold())
                    .frame(maxWidth: 100, alignment: .trailing)
            }
            controls(context.state, tint: .white, onTint: Self.accent)
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func controls(_ state: WorkoutActivityAttributes.ContentState, tint: Color, onTint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let exercise = state.currentExercise {
                HStack {
                    Text(exercise)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text("Set \(state.setNumber) of \(state.setsInExercise) · \(state.effort)")
                        .font(.subheadline)
                        .opacity(0.85)
                }

                HStack(spacing: 8) {
                    stepper("minus", delta: -WorkoutLiveAction.weightStep)
                    Text("\(state.weight.formatted(.number.precision(.fractionLength(0...1)))) lb")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    stepper("plus", delta: WorkoutLiveAction.weightStep)
                    Button(intent: LogSetIntent()) {
                        Label("Log", systemImage: "checkmark")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(onTint)
                    }
                    .tint(tint)
                    Button(intent: NextExerciseIntent()) {
                        Image(systemName: "forward.fill")
                            .font(.subheadline.bold())
                            .frame(width: 28)
                            .foregroundStyle(onTint)
                    }
                    .tint(tint.opacity(0.6))
                    .accessibilityLabel("Next Exercise")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("All sets logged — open the app to finish")
                    .font(.headline)
            }

            if let end = state.restEndDate, end > Date() {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("Rest")
                    Spacer()
                    Text(timerInterval: Date()...end, countsDown: true)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                .font(.subheadline.bold())
            }

            HStack(spacing: 8) {
                ProgressView(value: progress(state))
                    .tint(tint)
                Text("\(state.completedSets)/\(state.totalSets) sets")
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
    }

    private func stepper(_ symbol: String, delta: Double) -> some View {
        Button(intent: AdjustWeightIntent(delta: delta)) {
            Image(systemName: symbol)
                .font(.subheadline.bold())
                .frame(width: 28, height: 24)
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
