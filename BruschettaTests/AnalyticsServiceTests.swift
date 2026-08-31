import Testing
@testable import Bruschetta

struct AnalyticsServiceTests {
    @Test(arguments: [
        (-10.0, "0-25"),
        (0.0, "0-25"),
        (24.9, "0-25"),
        (25.0, "25-50"),
        (49.9, "25-50"),
        (50.0, "50-75"),
        (74.9, "50-75"),
        (75.0, "75-90"),
        (89.9, "75-90"),
        (90.0, "90-100"),
        (100.0, "90-100")
    ])
    func bracketLabelBucketsScoresIntoExpectedRanges(score: Double, expected: String) {
        #expect(AnalyticsService.bracketLabel(for: score) == expected)
    }
}
