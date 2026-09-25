import Foundation
import SwiftData

@Model
final class Category {
    var name: String = ""
    var icon: String = "circle.fill"
    var colorHex: String = "#9E9E9E"
    var sortOrder: Int = 0
    var includeInOverview: Bool = true

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill]? = []

    init(name: String, icon: String, colorHex: String, sortOrder: Int) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    static let defaultCategories: [(name: String, icon: String, colorHex: String)] = [
        ("Groceries", "cart.fill", "#4CAF50"),
        ("Restaurant", "fork.knife", "#FF7043"),
        ("Gas", "fuelpump.fill", "#FFA726"),
        ("Car Maintenance", "wrench.and.screwdriver.fill", "#78909C"),
        ("Entertainment", "tv.fill", "#AB47BC"),
        ("Shopping", "bag.fill", "#EC407A"),
        ("Medical", "cross.case.fill", "#EF5350"),
        ("Subscriptions", "repeat.circle.fill", "#5C6BC0"),
        ("Gym", "dumbbell.fill", "#8D6E63"),
        ("Donations", "heart.fill", "#E91E63"),
        ("Gambling", "die.face.5.fill", "#6A1B9A"),
        ("Tools", "wrench.fill", "#607D8B"),
        ("Materials", "shippingbox.fill", "#795548"),
        ("Other", "ellipsis.circle.fill", "#9E9E9E"),
        ("Housing", "house.fill", "#6D4C41"),
        ("Savings", "banknote.fill", "#2E7D32"),
        ("Investing", "chart.line.uptrend.xyaxis", "#1565C0"),
        ("Investments", "building.columns.fill", "#00695C"),
        ("Utilities", "bolt.fill", "#F9A825"),
        ("Internet", "wifi", "#5C6BC0"),
        ("Insurance", "shield.fill", "#37474F"),
        ("Phone", "phone.fill", "#00838F")
    ]

    static let savingsCategoryNames: Set<String> = ["Savings", "Investing", "Investments"]
    static let investingCategoryNames: Set<String> = ["Investing", "Investments"]

    var isSavingsOrInvesting: Bool {
        Category.savingsCategoryNames.contains(name)
    }

    var isInvestingCategory: Bool {
        Category.investingCategoryNames.contains(name)
    }

    var isSavingsCategory: Bool {
        isSavingsOrInvesting && !isInvestingCategory
    }
}
