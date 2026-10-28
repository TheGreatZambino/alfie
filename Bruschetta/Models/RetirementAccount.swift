import Foundation
import SwiftData

enum RetirementAccountType: String, CaseIterable, Identifiable {
    case k401 = "401(k)"
    case roth401k = "Roth 401(k)"
    case traditionalIRA = "Traditional IRA"
    case rothIRA = "Roth IRA"
    case k403b = "403(b)"
    case sepIRA = "SEP IRA"
    case other = "Other"

    var id: String { rawValue }
}

@Model
final class RetirementAccount {
    var name: String = ""
    var typeRaw: String = RetirementAccountType.k401.rawValue
    var balance: Double = 0

    var type: RetirementAccountType {
        get { RetirementAccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(name: String, type: RetirementAccountType = .k401, balance: Double = 0) {
        self.name = name
        self.typeRaw = type.rawValue
        self.balance = balance
    }
}
