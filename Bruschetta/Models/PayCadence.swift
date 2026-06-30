import Foundation

enum PayCadence: String, Codable, CaseIterable {
    case weekly = "Weekly"
    case biweekly = "Bi-Weekly"
    case semiMonthly = "Semi-Monthly"
    case monthly = "Monthly"

    var displayName: String { rawValue }

    var periodsPerMonth: Double {
        switch self {
        case .weekly: return 4.33
        case .biweekly: return 2.165
        case .semiMonthly: return 2
        case .monthly: return 1
        }
    }
}
