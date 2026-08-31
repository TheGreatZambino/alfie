import Testing
import SwiftUI
@testable import Bruschetta

struct ColorHexTests {
    private func rgbComponents(fromHex hex: String) -> (Int, Int, Int) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        return (Int((value & 0xFF0000) >> 16), Int((value & 0x00FF00) >> 8), Int(value & 0x0000FF))
    }

    /// Allows a rounding tolerance of 1 per channel since `toHex()` round-trips through
    /// `UIColor`, which can introduce sub-integer floating point drift.
    @Test(arguments: ["#4CAF50", "#FF7043", "#000000", "#FFFFFF", "#9E9E9E"])
    func hexInitRoundTripsApproximatelyThroughToHex(hex: String) {
        let expected = rgbComponents(fromHex: hex)
        let actual = rgbComponents(fromHex: Color(hex: hex).toHex())

        #expect(abs(expected.0 - actual.0) <= 1)
        #expect(abs(expected.1 - actual.1) <= 1)
        #expect(abs(expected.2 - actual.2) <= 1)
    }

    @Test
    func hexInitIsCaseInsensitive() {
        #expect(Color(hex: "#4caf50").toHex() == Color(hex: "#4CAF50").toHex())
    }

    @Test
    func hexInitToleratesMissingHashPrefix() {
        #expect(Color(hex: "4CAF50").toHex() == Color(hex: "#4CAF50").toHex())
    }
}
