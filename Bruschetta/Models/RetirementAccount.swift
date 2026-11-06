import Foundation
import SwiftData

enum RetirementAccountType: String, CaseIterable, Identifiable {
    case k401 = "401(k)"
    case roth401k = "Roth 401(k)"
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case k403b = "403(b)"
    case sepIRA = "SEP IRA"
    case brokerage = "Brokerage"
    case other = "Other"

    var id: String { rawValue }

    var bucket: TaxBucket {
        switch self {
        case .k401, .k403b, .traditionalIRA, .sepIRA, .other: return .preTax
        case .roth401k, .rothIRA: return .roth
        case .brokerage: return .taxable
        }
    }
}

/// How an account's withdrawals are taxed in retirement. "Other" accounts are treated as
/// pre-tax, the conservative assumption.
enum TaxBucket: String, CaseIterable, Identifiable {
    case preTax
    case roth
    case taxable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preTax: return "Pre-tax"
        case .roth: return "Roth"
        case .taxable: return "Taxable"
        }
    }

    var explanation: String {
        switch self {
        case .preTax: return "Withdrawals are taxed as ordinary income."
        case .roth: return "Qualified withdrawals are tax-free."
        case .taxable: return "Only investment gains are taxed when you sell."
        }
    }

    var icon: String {
        switch self {
        case .preTax: return "building.columns"
        case .roth: return "leaf"
        case .taxable: return "chart.line.uptrend.xyaxis"
        }
    }
}

@Model
final class RetirementAccount {
    var name: String = ""
    var typeRaw: String = RetirementAccountType.k401.rawValue
    var balance: Double = 0
    /// Index of the plan person who owns the account (0 = first person, 1 = partner).
    var ownerOrder: Int = 0
    /// When the balance was last confirmed. Nil means it has never been confirmed in the
    /// Retirement tab, so it's treated as stale.
    var balanceUpdatedAt: Date?
    /// What the owner contributes each month, before any employer contribution.
    var monthlyEmployeeContribution: Double = 0
    /// What an employer adds each month (match or profit sharing).
    var monthlyEmployerContribution: Double = 0
    /// Share of the account held in stocks, 0 to 100. The rest is treated as bonds.
    var stockAllocationPercent: Double = 60

    var type: RetirementAccountType {
        get { RetirementAccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var bucket: TaxBucket { type.bucket }

    var monthlyContribution: Double { monthlyEmployeeContribution + monthlyEmployerContribution }

    init(name: String, type: RetirementAccountType = .k401, balance: Double = 0, ownerOrder: Int = 0) {
        self.name = name
        self.typeRaw = type.rawValue
        self.balance = balance
        self.ownerOrder = ownerOrder
        self.balanceUpdatedAt = Date()
    }

    /// Sets a new balance and records that the user just confirmed it.
    func updateBalance(_ newBalance: Double) {
        balance = newBalance
        balanceUpdatedAt = Date()
    }

    /// Marks the current balance as still correct.
    func confirmBalance() {
        balanceUpdatedAt = Date()
    }

    var daysSinceUpdate: Int? {
        guard let balanceUpdatedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: balanceUpdatedAt, to: Date()).day
    }

    var freshness: BalanceFreshness {
        guard let days = daysSinceUpdate else { return .stale }
        if days < BalanceFreshness.agingAfterDays { return .fresh }
        if days < BalanceFreshness.staleAfterDays { return .aging }
        return .stale
    }
}

enum BalanceFreshness {
    case fresh, aging, stale

    static let agingAfterDays = 30
    static let staleAfterDays = 90
}
