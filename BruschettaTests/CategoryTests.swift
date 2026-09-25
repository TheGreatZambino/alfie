import Testing
import Foundation
@testable import Bruschetta

struct CategoryTests {
    @Test(arguments: ["Savings", "Investing", "Investments"])
    func savingsCategoryNamesAreFlaggedAsSavingsOrInvesting(name: String) {
        let category = Category(name: name, icon: "circle", colorHex: "#000000", sortOrder: 0)
        #expect(category.isSavingsOrInvesting)
    }

    @Test
    func nonSavingsCategoryIsNotFlagged() {
        let category = Category(name: "Groceries", icon: "cart.fill", colorHex: "#4CAF50", sortOrder: 0)
        #expect(!category.isSavingsOrInvesting)
    }

    @Test
    func defaultCategoryNamesAreUnique() {
        let names = Category.defaultCategories.map(\.name)
        #expect(Set(names).count == names.count)
    }
}
