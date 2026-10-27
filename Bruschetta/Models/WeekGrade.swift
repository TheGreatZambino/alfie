import SwiftUI

/// Letter grade for the Overview week score (0–100), A (best) through E (worst).
/// Shares its letters and colors with `FoodGrade` so the two read as one system.
enum WeekGrade: CaseIterable, Comparable {
    case a, b, c, d, e

    /// Declared best-first, so `.a < .b` (a better grade sorts earlier).
    static func < (lhs: WeekGrade, rhs: WeekGrade) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    init(score: Double) {
        switch score {
        case 90...: self = .a
        case 75..<90: self = .b
        case 55..<75: self = .c
        case 35..<55: self = .d
        default: self = .e
        }
    }

    var verdict: String {
        switch self {
        case .a: return "Outstanding week"
        case .b: return "Strong week"
        case .c: return "Good week so far"
        case .d: return "Slow week"
        case .e: return "Rough week"
        }
    }

    /// One-word pillar status, shown under each ring and read out by Siri.
    var status: String {
        switch self {
        case .a: return "Ahead"
        case .b: return "Strong"
        case .c: return "On pace"
        case .d: return "Slipping"
        case .e: return "Behind"
        }
    }

    /// C or better counts as on track.
    var isOnTrack: Bool { self <= .c }

    var foodGrade: FoodGrade {
        switch self {
        case .a: return .a
        case .b: return .b
        case .c: return .c
        case .d: return .d
        case .e: return .e
        }
    }
}
