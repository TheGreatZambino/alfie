import Foundation
import SwiftData

@Model
final class SavingsAccount {
    var name: String = ""
    var balance: Double = 0
    var allocationPerPaycheck: Double = 0
    var lastReconciledPeriodEnd: Date?

    init(name: String, balance: Double = 0, allocationPerPaycheck: Double = 0, lastReconciledPeriodEnd: Date? = nil) {
        self.name = name
        self.balance = balance
        self.allocationPerPaycheck = allocationPerPaycheck
        self.lastReconciledPeriodEnd = lastReconciledPeriodEnd
    }
}
