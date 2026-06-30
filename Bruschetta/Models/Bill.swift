import Foundation
import SwiftData

@Model
final class Bill {
    var name: String = ""
    var amount: Double = 0
    var allocationAmount: Double = 0
    var dueDay: Int = 1
    var category: Category?
    var isActive: Bool = true
    var notes: String?

    init(name: String, amount: Double, allocationAmount: Double? = nil, dueDay: Int, category: Category? = nil, isActive: Bool = true, notes: String? = nil) {
        self.name = name
        self.amount = amount
        self.allocationAmount = allocationAmount ?? amount
        self.dueDay = dueDay
        self.category = category
        self.isActive = isActive
        self.notes = notes
    }
}
