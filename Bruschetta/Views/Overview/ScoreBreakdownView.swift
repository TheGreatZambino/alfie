import SwiftUI

/// Expanded view of the week score: what's behind each pillar's grade and where to improve.
struct ScoreBreakdownView: View {
    @ObservedObject var viewModel: OverviewViewModel
    let trackedModules: Set<TrackedModule>
    @Environment(\.dismiss) private var dismiss

    private struct Pillar: Identifiable {
        let name: String
        let color: Color
        let score: Double
        let components: [ScoreComponent]
        var id: String { name }
    }

    private var pillars: [Pillar] {
        var result: [Pillar] = []
        if trackedModules.contains(.finance) {
            result.append(Pillar(name: "Finances", color: .money, score: viewModel.expenseScore, components: viewModel.expenseComponents))
        }
        if trackedModules.contains(.workouts) {
            result.append(Pillar(name: "Workouts", color: .training, score: viewModel.workoutScore, components: viewModel.workoutComponents))
        }
        if trackedModules.contains(.nutrition) {
            result.append(Pillar(name: "Nutrition", color: .food, score: viewModel.calorieScore, components: viewModel.nutritionComponents))
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overallCard
                    ForEach(pillars) { pillar in
                        pillarCard(pillar)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color.paper)
            .navigationTitle("Score breakdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var overallCard: some View {
        let grade = WeekGrade(score: viewModel.overallScore)
        let comparison = WeekSummary.make(pillars: pillars.map { ($0.name, $0.score) })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                GradeBadge(grade: grade.foodGrade, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(grade.verdict)
                        .font(.screenHeadline)
                        .foregroundStyle(Color.ink)
                    Text("\(Int(viewModel.overallScore.rounded())) out of 100")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkTertiary)
                }
            }
            if !comparison.isEmpty {
                Text(comparison)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func pillarCard(_ pillar: Pillar) -> some View {
        let grade = WeekGrade(score: pillar.score)
        let summary = PillarSummary.make(score: pillar.score, components: pillar.components)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GradeBadge(grade: grade.foodGrade, size: 24)
                Text(pillar.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("\(Int(pillar.score.rounded()))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
            Text(summary.headline)
                .font(.system(size: 14))
                .foregroundStyle(Color.inkSecondary)
            ForEach(pillar.components) { component in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(component.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.ink)
                        Spacer()
                        Text(component.detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkTertiary)
                    }
                    ProgressView(value: min(1, max(0, component.displayProgress)))
                        .tint(pillar.color)
                }
                .accessibilityElement(children: .combine)
            }
            if let focus = summary.focus {
                Text(focus)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(pillar.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
