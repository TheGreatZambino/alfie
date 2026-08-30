import SwiftUI

struct WidgetWorkoutView: View {
    let snapshot: WidgetWorkoutSnapshot

    private static let accent = Color(red: 13.0 / 255, green: 115.0 / 255, blue: 119.0 / 255)

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(title: "Cardio", icon: "figure.run") {
                if let cardio = snapshot.cardio {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cardio.activityName)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(cardioSubtitle(cardio))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No Cardio Workout tracked today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            column(title: "Strength", icon: "figure.strengthtraining.traditional") {
                if let strength = snapshot.strength {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strength.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text("\(Int(strength.totalVolume)) lb · \(strength.exerciseCount) ex\(strength.exerciseCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No Strength Workout tracked today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    private func cardioSubtitle(_ cardio: CardioWorkoutSnapshot) -> String {
        var parts = ["\(cardio.durationMinutes) min"]
        if let distance = cardio.distanceMiles, distance > 0.05 {
            parts.append(String(format: "%.1f mi", distance))
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func column<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(Self.accent)
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
