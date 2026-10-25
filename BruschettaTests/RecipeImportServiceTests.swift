import XCTest
@testable import Bruschetta

final class RecipeImportServiceTests: XCTestCase {
    func testParsesGraphRecipeWithHowToSteps() {
        let html = """
        <html><script type="application/ld+json">
        {"@context":"https://schema.org","@graph":[{"@type":"WebSite"},
        {"@type":"Recipe","name":"Garlic Pasta Recipe by Tasty","description":"Easy &amp; quick",
         "image":["https://x.com/a.jpg"],"recipeYield":["4","4 servings"],"totalTime":"PT1H15M",
         "recipeIngredient":["2 tbsp butter","4 cloves garlic"],
         "recipeInstructions":[{"@type":"HowToStep","text":"Melt butter."},{"@type":"HowToStep","text":"Add garlic."}]}]}
        </script></html>
        """
        let r = RecipeImportService.parse(html: html)
        XCTAssertEqual(r?.name, "Garlic Pasta")
        XCTAssertEqual(r?.summary, "Easy & quick")
        XCTAssertEqual(r?.servings, 4)
        XCTAssertEqual(r?.prepMinutes, 75)
        XCTAssertEqual(r?.ingredients.count, 2)
        XCTAssertEqual(r?.steps, ["Melt butter.", "Add garlic."])
        XCTAssertEqual(r?.imageURL?.absoluteString, "https://x.com/a.jpg")
    }

    func testReturnsNilWithoutRecipe() {
        XCTAssertNil(RecipeImportService.parse(html: "<html><body>Hello</body></html>"))
    }

    func testFormatDuration() {
        XCTAssertEqual(Recipe.formatDuration(minutes: 102), "1 hr 42 min")
        XCTAssertEqual(Recipe.formatDuration(minutes: 45), "45 min")
        XCTAssertEqual(Recipe.formatDuration(minutes: 120), "2 hr")
    }
}
