import SwiftUI

/// Minutes/seconds duration input built from two `SelectAllIntTextField`s,
/// used wherever a movement is tracked by time (e.g. planks) instead of reps.
struct DurationField: View {
    @Binding var totalSeconds: Int

    private var minutes: Binding<Int> {
        Binding(
            get: { totalSeconds / 60 },
            set: { totalSeconds = $0 * 60 + totalSeconds % 60 }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { totalSeconds % 60 },
            set: { totalSeconds = (totalSeconds / 60) * 60 + max(0, min($0, 59)) }
        )
    }

    var body: some View {
        HStack(spacing: 2) {
            SelectAllIntTextField(value: minutes)
                .frame(width: 22)
            Text(":")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            SelectAllIntTextField(value: seconds)
                .frame(width: 22)
        }
    }
}
