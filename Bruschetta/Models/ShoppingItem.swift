import Foundation
import SwiftData

@Model
final class ShoppingItem {
    var name: String = ""
    var quantity: Int = 1
    var estimatedPrice: Double = 0
    var isChecked: Bool = false
    var createdAt: Date = Date()
    /// Set when the item is bought and logged as an expense; purchased items leave the active list.
    var transaction: Transaction?

    init(name: String, quantity: Int = 1, estimatedPrice: Double = 0) {
        self.name = name
        self.quantity = quantity
        self.estimatedPrice = estimatedPrice
    }

    var estimatedTotal: Double { estimatedPrice * Double(quantity) }
}

/// A saved, re-usable shopping list.
@Model
final class ShoppingListTemplate {
    var name: String = ""
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \ShoppingTemplateItem.template)
    var items: [ShoppingTemplateItem]? = []

    init(name: String) {
        self.name = name
    }

    var sortedItems: [ShoppingTemplateItem] {
        (items ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

@Model
final class ShoppingTemplateItem {
    var name: String = ""
    var quantity: Int = 1
    var estimatedPrice: Double = 0
    var sortOrder: Int = 0
    var template: ShoppingListTemplate?

    init(name: String, quantity: Int, estimatedPrice: Double, sortOrder: Int) {
        self.name = name
        self.quantity = quantity
        self.estimatedPrice = estimatedPrice
        self.sortOrder = sortOrder
    }
}
