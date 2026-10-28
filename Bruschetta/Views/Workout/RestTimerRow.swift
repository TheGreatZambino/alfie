import SwiftUI

/// Small note shown under an exercise that has a rest timer, pointing to the sound setting.
struct RestSoundNote: View {
    var body: some View {
        Label("Change the rest timer sound in Settings › Workout Goals.", systemImage: "speaker.wave.2")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "Rest" control shown under a set: -/+ buttons step in 15s increments, and the
/// min:sec fields accept any custom value. Zero means no rest timer.
struct RestTimerRow: View {
    static let step = 15

    /// "15s" under a minute, "1:30" from a minute up.
    static func label(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)s" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    @Binding var seconds: Int
    @State private var isEditing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(seconds > 0 ? Color.training : Color.secondary)
                .frame(width: 24)

            Text("Rest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                stepButton(systemName: "minus", delta: -Self.step)

                if seconds > 0 && isEditing {
                    DurationField(totalSeconds: $seconds)
                    Button {
                        isEditing = false
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.training)
                            .frame(width: 24, height: 32)
                            .tapTarget(layoutWidth: 24, layoutHeight: 32)
                    }
                    .buttonStyle(.plain)
                } else if seconds > 0 {
                    Text(Self.label(seconds))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .frame(minWidth: 47)
                        .contentShape(Rectangle())
                        .onTapGesture { isEditing = true }
                } else {
                    Text("Off")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 47)
                }

                stepButton(systemName: "plus", delta: Self.step)
            }
            .padding(.horizontal, 2)
            .background(Color.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Spacer(minLength: 0)

            if seconds > 0 {
                Button {
                    seconds = 0
                    isEditing = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove rest timer")
            }
        }
    }

    private func stepButton(systemName: String, delta: Int) -> some View {
        Button {
            // Snap to the next multiple of the step so custom values realign.
            let step = Self.step
            let snapped = delta > 0 ? (seconds / step + 1) * step : ((seconds + step - 1) / step - 1) * step
            seconds = max(0, snapped)
            isEditing = false
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.training)
                .frame(width: 32, height: 32)
                .tapTarget(layoutWidth: 32, layoutHeight: 32)
        }
        .buttonStyle(.plain)
    }
}

/// Which sets a bulk rest change applies to: one exercise, or the whole workout when `entryID` is nil.
struct RestBulkTarget: Identifiable {
    let id = UUID()
    var entryID: UUID?
    var title: String
    var initialSeconds: Int
}

/// Sheet for setting (or removing) the rest timer on every set in a movement or workout at once.
struct BulkRestSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: RestBulkTarget
    let onApply: (Int) -> Void

    @State private var seconds: Int

    init(target: RestBulkTarget, onApply: @escaping (Int) -> Void) {
        self.target = target
        self.onApply = onApply
        _seconds = State(initialValue: target.initialSeconds > 0 ? target.initialSeconds : 60)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Set the same rest after every set. You can still adjust individual sets afterward.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                RestTimerRow(seconds: $seconds)

                Button {
                    onApply(seconds)
                    dismiss()
                } label: {
                    Text(seconds > 0 ? "Apply to All Sets" : "Remove All Rest Timers")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.trainingFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                if seconds > 0 {
                    Button(role: .destructive) {
                        onApply(0)
                        dismiss()
                    } label: {
                        Text("Remove All Rest Timers")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}
