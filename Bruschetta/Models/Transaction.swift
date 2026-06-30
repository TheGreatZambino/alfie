import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Double = 0
    var date: Date = Date()
    var note: String?
    var category: Category?

    init(amount: Double, date: Date, note: String? = nil, category: Category? = nil) {
        self.amount = amount
        self.date = date
        self.note = note
        self.category = category
    }
}
