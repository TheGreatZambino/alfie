import SwiftUI

/// Presents the active workout full screen and, while it's minimized, docks a mini bar above the
/// tab bar so the rest of the app stays usable.
private struct ActiveWorkoutCover: ViewModifier {
    @ObservedObject private var session = ActiveWorkoutSession.shared

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $session.isPresented) {
                ActiveWorkoutView()
            }
    }
}

private struct ActiveWorkoutBarInset: ViewModifier {
    @ObservedObject private var session = ActiveWorkoutSession.shared

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if session.isActive && !session.isPresented {
                ActiveWorkoutMiniBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: session.isActive && !session.isPresented)
    }
}

extension View {
    /// Attach once, high in the hierarchy, to present the running workout.
    func activeWorkoutCover() -> some View { modifier(ActiveWorkoutCover()) }
    /// Attach to each tab's root so the minimized-workout bar sits above the tab bar.
    func activeWorkoutBar() -> some View { modifier(ActiveWorkoutBarInset()) }
}

private struct ActiveWorkoutMiniBar: View {
    @ObservedObject private var session = ActiveWorkoutSession.shared

    var body: some View {
        Button {
            session.expand()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.plan?.name ?? "Workout")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("\(session.completedSets) of \(session.totalSets) sets")
                        .font(.system(size: 12))
                        .opacity(0.8)
                }

                Spacer(minLength: 8)

                if let restEnd = session.restEndDate {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text(timerInterval: Date.now...max(restEnd, Date.now), countsDown: true)
                            .monospacedDigit()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(.white.opacity(0.22)))
                } else {
                    Text(session.startTime, style: .timer)
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.trainingFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Return to workout")
    }
}
