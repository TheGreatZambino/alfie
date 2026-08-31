import Testing
@testable import Bruschetta

struct PayCadenceTests {
    @Test
    func displayNameMatchesRawValue() {
        for cadence in PayCadence.allCases {
            #expect(cadence.displayName == cadence.rawValue)
        }
    }

    @Test(arguments: [
        (PayCadence.weekly, 4.33),
        (PayCadence.biweekly, 2.165),
        (PayCadence.semiMonthly, 2.0),
        (PayCadence.monthly, 1.0)
    ])
    func periodsPerMonth(cadence: PayCadence, expected: Double) {
        #expect(cadence.periodsPerMonth == expected)
    }
}
