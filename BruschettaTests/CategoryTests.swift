import Testing
import Foundation
@testable import Bruschetta

struct CategoryTests {
    @Test
    func typeGetterFallsBackToSpendingForUnknownRawValue() {
        let category = Category(name: "Test", icon: "circle", colorHex: "#000000", type: .bill, sortOrder: 0)
        category.typeRaw = "not-a-real-type"
        #expect(category.type == .spending)
    }

    @Test
    func typeSetterRoundTrips() {
        let category = Category(name: "Test", icon: "circle", colorHex: "#000000", type: .spending, sortOrder: 0)
        category.type = .bill
        #expect(category.typeRaw == CategoryType.bill.rawValue)
        #expect(category.type == .bill)
    }

    @Test(arguments: ["Savings", "Investing", "Investments"])
    func savingsCategoryNamesAreFlaggedAsSavingsOrInvesting(name: String) {
        let category = Category(name: name, icon: "circle", colorHex: "#000000", type: .bill, sortOrder: 0)
        #expect(category.isSavingsOrInvesting)
    }

    @Test
    func nonSavingsCategoryIsNotFlagged() {
        let category = Category(name: "Groceries", icon: "cart.fill", colorHex: "#4CAF50", type: .spending, sortOrder: 0)
        #expect(!category.isSavingsOrInvesting)
    }

    @Test
    func defaultCategoryNamesAreUnique() {
        let spendingNames = Category.defaultSpendingCategories.map(\.name)
        let billNames = Category.defaultBillCategories.map(\.name)
        #expect(Set(spendingNames).count == spendingNames.count)
        #expect(Set(billNames).count == billNames.count)
    }
}
