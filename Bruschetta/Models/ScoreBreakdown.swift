import Foundation

/// One input to a pillar score, shown as a row in the expanded breakdown.
struct ScoreComponent: Identifiable, Equatable {
    let name: String
    /// 0...1 credit earned toward this input.
    let progress: Double
    /// Plain-language numbers behind the progress, e.g. "2 of 3 this week".
    let detail: String
    var isTracked: Bool = true

    var id: String { name }
}

/// Hard-coded plain-language read on a pillar: a headline from its grade and a pointer to
/// the weakest input. Deterministic and fully local, so it's testable and works offline.
struct PillarSummary: Equatable {
    let headline: String
    let focus: String?

    /// Inputs at or above this credit are treated as on target.
    static let onTargetThreshold = 0.95

    static func make(score: Double, components: [ScoreComponent]) -> PillarSummary {
        let headline: String
        switch WeekGrade(score: score) {
        case .a: headline = "Excellent — nearly everything is on target."
        case .b: headline = "Strong — just a little room to improve."
        case .c: headline = "On pace — a few things to tighten up."
        case .d: headline = "Slipping — some goals need attention."
        case .e: headline = "Behind — this needs attention."
        }
        guard let weakest = components.min(by: { $0.progress < $1.progress }),
              weakest.progress < onTargetThreshold else {
            return PillarSummary(headline: headline, focus: nil)
        }
        return PillarSummary(headline: headline, focus: "Biggest opportunity: \(weakest.name.lowercased()) (\(weakest.detail)).")
    }
}

enum WeekSummary {
    /// One sentence naming the strongest and weakest tracked pillars. Empty with fewer than
    /// two pillars, where there is nothing to compare.
    static func make(pillars: [(name: String, score: Double)]) -> String {
        guard pillars.count >= 2,
              let best = pillars.max(by: { $0.score < $1.score }),
              let worst = pillars.min(by: { $0.score < $1.score }) else { return "" }
        if best.score - worst.score < 10 {
            return "All your pillars are moving together."
        }
        return "\(best.name) is leading the way; \(worst.name.lowercased()) is pulling your score down the most."
    }
}
