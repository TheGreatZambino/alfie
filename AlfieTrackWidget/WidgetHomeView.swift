import SwiftUI
import WidgetKit

struct WidgetHomeView: View {
    let snapshot: WidgetWorkoutSnapshot
    let configuration: HomeWidgetConfigurationIntent

    @Environment(\.widgetFamily) private var family

    private static let accent = Color(red: 13.0 / 255, green: 115.0 / 255, blue: 119.0 / 255)

    private var isCompact: Bool { family == .systemMedium }

    var body: some View {
        let sections = isCompact ? configuration.compactSections : configuration.orderedSections
        VStack(alignment: .leading, spacing: isCompact ? 8 : 14) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, option in
                sectionView(for: option)
                if index < sections.count - 1 {
                    Divider()
                }
            }
        }
        .padding(isCompact ? 12 : 16)
    }

    @ViewBuilder
    private func sectionView(for option: HomeWidgetSection) -> some View {
        switch option {
        case .finance: financeRow
        case .nutrition: nutritionRow
        case .workouts: workoutRow
        case .water: waterRow
        case .none: EmptyView()
        }
    }

    // MARK: - Finance

    @ViewBuilder
    private var financeRow: some View {
        if isCompact {
            compactLine(icon: "dollarsign.circle") {
                if let finance = snapshot.finance {
                    Text(finance.remainingThisPeriod, format: .currency(code: "USD"))
                        .font(.subheadline.bold())
                        .foregroundStyle(finance.remainingThisPeriod >= 0 ? Self.accent : .red)
                    Text("left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    if let periodEnd = finance.periodEnd {
                        Text(periodEnd, format: .dateTime.month(.abbreviated).day())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    placeholder("Set up income in Settings")
                }
            }
        } else {
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
    }

    // MARK: - Nutrition

    @ViewBuilder
    private var nutritionRow: some View {
        if isCompact {
            compactLine(icon: "fork.knife") {
                if let nutrition = snapshot.nutrition {
                    Text("\(Int(nutrition.caloriesToday).formatted())/\(Int(nutrition.calorieGoal).formatted()) cal")
                        .font(.subheadline.bold())
                    Spacer(minLength: 8)
                    ProgressView(value: min(nutrition.caloriesToday, nutrition.calorieGoal), total: max(nutrition.calorieGoal, 1))
                        .tint(Self.accent)
                        .frame(width: 44)
                } else {
                    placeholder("No food logged yet today")
                }
            }
        } else {
            section(title: "Nutrition", icon: "fork.knife") {
                if let nutrition = snapshot.nutrition {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(nutrition.caloriesToday).formatted()) cal")
                                .font(.subheadline.bold())
                            Text("of \(Int(nutrition.calorieGoal).formatted()) goal")
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
    }

    // MARK: - Water

    @ViewBuilder
    private var waterRow: some View {
        if isCompact {
            compactLine(icon: "drop.fill") {
                if let water = snapshot.water {
                    Text("\(Int(water.ouncesToday))/\(Int(water.goalOunces)) oz")
                        .font(.subheadline.bold())
                    Spacer(minLength: 8)
                    ProgressView(value: min(water.ouncesToday, water.goalOunces), total: max(water.goalOunces, 1))
                        .tint(Self.accent)
                        .frame(width: 44)
                } else {
                    placeholder("No water logged yet today")
                }
            }
        } else {
            section(title: "Water", icon: "drop.fill") {
                if let water = snapshot.water {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(water.ouncesToday)) oz")
                                .font(.subheadline.bold())
                            Text("of \(Int(water.goalOunces)) goal")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        ProgressView(value: min(water.ouncesToday, water.goalOunces), total: max(water.goalOunces, 1))
                            .tint(Self.accent)
                    }
                } else {
                    placeholder("No water logged yet today")
                }
            }
        }
    }

    // MARK: - Workouts

    @ViewBuilder
    private var workoutRow: some View {
        if isCompact {
            VStack(alignment: .leading, spacing: 4) {
                if snapshot.cardio == nil && snapshot.strength == nil {
                    compactLine(icon: "figure.run") {
                        placeholder("No workouts logged today")
                    }
                } else {
                    if let cardio = snapshot.cardio {
                        compactLine(icon: "figure.run") { cardioDetail(cardio) }
                    }
                    if let strength = snapshot.strength {
                        compactLine(icon: "figure.strengthtraining.traditional") { strengthDetail(strength) }
                    }
                }
            }
        } else {
            switch (snapshot.cardio, snapshot.strength) {
            case let (cardio?, strength?):
                HStack(alignment: .top, spacing: 12) {
                    section(title: "Cardio", icon: "figure.run") { cardioDetail(cardio) }
                    Divider()
                    section(title: "Strength", icon: "figure.strengthtraining.traditional") { strengthDetail(strength) }
                }
            case let (cardio?, nil):
                section(title: "Cardio", icon: "figure.run") { cardioDetail(cardio) }
            case let (nil, strength?):
                section(title: "Strength", icon: "figure.strengthtraining.traditional") { strengthDetail(strength) }
            case (nil, nil):
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundStyle(Self.accent)
                    placeholder("No workouts logged today")
                }
            }
        }
    }

    private func cardioDetail(_ cardio: CardioWorkoutSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(cardio.activityName)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text(cardioSubtitle(cardio))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func strengthDetail(_ strength: StrengthWorkoutSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(strength.name)
                .font(.subheadline.bold())
                .lineLimit(1)
            Text("\(Int(strength.totalVolume)) lb · \(strength.exerciseCount) ex\(strength.exerciseCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    /// A single-line "icon + content" row used by the compact (.systemMedium) layout.
    @ViewBuilder
    private func compactLine<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Self.accent)
            content()
        }
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
