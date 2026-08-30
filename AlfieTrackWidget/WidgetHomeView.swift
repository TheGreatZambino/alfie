import SwiftUI

struct WidgetHomeView: View {
    let snapshot: WidgetWorkoutSnapshot

    private static let accent = Color(red: 13.0 / 255, green: 115.0 / 255, blue: 119.0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            financeRow
            Divider()
            nutritionRow
            Divider()
            workoutRow
        }
        .padding()
    }

    private var workoutRow: some View {
        HStack(alignment: .top, spacing: 12) {
            section(title: "Cardio", icon: "figure.run") {
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
                    placeholder("No cardio yet today")
                }
            }

            Divider()

            section(title: "Strength", icon: "figure.strengthtraining.traditional") {
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
                    placeholder("No strength yet today")
                }
            }
        }
    }

    private var financeRow: some View {
        section(title: "Finances", icon: "dollarsign.circle") {
            if let finance = snapshot.finance {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(finance.remainingThisPeriod, format: .currency(code: "USD"))
                            .font(.subheadline.bold())
                            .foregroundStyle(finance.remainingThisPeriod >= 0 ? Self.accent : .red)
                        Text("remaining this period")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let periodEnd = finance.periodEnd {
                        Text(periodEnd, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                placeholder("Set up income in Settings")
            }
        }
    }

    private var nutritionRow: some View {
        section(title: "Nutrition", icon: "fork.knife") {
            if let nutrition = snapshot.nutrition {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(nutrition.caloriesToday)) cal")
                            .font(.subheadline.bold())
                        Text("of \(Int(nutrition.calorieGoal)) goal")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(nutrition.caloriesToday, nutrition.calorieGoal), total: max(nutrition.calorieGoal, 1))
                        .tint(Self.accent)
                }
            } else {
                placeholder("No food logged yet today")
            }
        }
    }

    private func cardioSubtitle(_ cardio: CardioWorkoutSnapshot) -> String {
        var parts = ["\(cardio.durationMinutes) min"]
        if let distance = cardio.distanceMiles, distance > 0.05 {
            parts.append(String(format: "%.1f mi", distance))
        }
        return parts.joined(separator: " · ")
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(Self.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
