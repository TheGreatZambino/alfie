import Foundation
import SwiftData

enum CategoryType: String, Codable, CaseIterable {
    case bill
    case spending
}

@Model
final class Category {
    var name: String = ""
    var icon: String = "circle.fill"
    var colorHex: String = "#9E9E9E"
    var typeRaw: String = CategoryType.spending.rawValue
    var sortOrder: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]? = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill]? = []

    init(name: String, icon: String, colorHex: String, type: CategoryType, sortOrder: Int) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.typeRaw = type.rawValue
        self.sortOrder = sortOrder
    }

    var type: CategoryType {
        get { CategoryType(rawValue: typeRaw) ?? .spending }
        set { typeRaw = newValue.rawValue }
    }

    static let defaultSpendingCategories: [(name: String, icon: String, colorHex: String)] = [
        ("Groceries", "cart.fill", "#4CAF50"),
        ("Restaurant", "fork.knife", "#FF7043"),
        ("Gas", "fuelpump.fill", "#FFA726"),
        ("Car Maintenance", "wrench.and.screwdriver.fill", "#78909C"),
        ("Entertainment", "tv.fill", "#AB47BC"),
        ("Shopping", "bag.fill", "#EC407A"),
        ("Medical", "cross.case.fill", "#EF5350"),
        ("Subscriptions", "repeat.circle.fill", "#5C6BC0"),
        ("Other", "ellipsis.circle.fill", "#9E9E9E")
    ]

    static let defaultBillCategories: [(name: String, icon: String, colorHex: String)] = [
        ("Housing", "house.fill", "#6D4C41"),
        ("Savings", "banknote.fill", "#2E7D32"),
        ("Investing", "chart.line.uptrend.xyaxis", "#1565C0"),
        ("Utilities", "bolt.fill", "#F9A825"),
        ("Internet", "wifi", "#5C6BC0")
    ]

    static let savingsCategoryNames: Set<String> = ["Savings", "Investing"]

    var isSavingsOrInvesting: Bool {
        Category.savingsCategoryNames.contains(name)
    }
}
