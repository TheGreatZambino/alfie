import Testing
import Foundation
@testable import Bruschetta

struct PayPeriodCalculatorTests {
    private let cal = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    // MARK: - PayPeriod.contains(day:)

    @Test
    func containsWithinSameMonth() {
        let period = PayPeriod(start: date(2026, 3, 10), end: date(2026, 3, 20, hour: 23, minute: 59, second: 59))
        #expect(period.contains(day: 15))
        #expect(period.contains(day: 10))
        #expect(period.contains(day: 20))
        #expect(!period.contains(day: 9))
        #expect(!period.contains(day: 21))
    }

    @Test
    func containsAcrossMonthBoundary() {
        // Period runs from the 28th of one month through the 5th of the next.
        let period = PayPeriod(start: date(2026, 3, 28), end: date(2026, 4, 5, hour: 23, minute: 59, second: 59))
        #expect(period.contains(day: 30))
        #expect(period.contains(day: 3))
        #expect(period.contains(day: 28))
        #expect(period.contains(day: 5))
        #expect(!period.contains(day: 15))
    }

    // MARK: - nextPayDate(after:cadence:)

    @Test
    func nextPayDateWeeklyAddsSevenDays() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 3, 1), cadence: .weekly)
        #expect(cal.isDate(next, inSameDayAs: date(2026, 3, 8)))
    }

    @Test
    func nextPayDateBiweeklyAddsFourteenDays() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 3, 1), cadence: .biweekly)
        #expect(cal.isDate(next, inSameDayAs: date(2026, 3, 15)))
    }

    @Test
    func nextPayDateMonthlyAddsOneMonth() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 1, 31), cadence: .monthly)
        #expect(cal.component(.month, from: next) == 2)
    }

    @Test
    func nextPayDateSemiMonthlyBeforeFifteenthGoesToFifteenth() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 3, 5), cadence: .semiMonthly)
        #expect(cal.isDate(next, inSameDayAs: date(2026, 3, 15)))
    }

    @Test
    func nextPayDateSemiMonthlyOnOrAfterFifteenthGoesToNextMonthFirst() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 3, 20), cadence: .semiMonthly)
        #expect(cal.isDate(next, inSameDayAs: date(2026, 4, 1)))
    }

    @Test
    func nextPayDateSemiMonthlyRollsOverIntoNextYear() {
        let next = PayPeriodCalculator.nextPayDate(after: date(2026, 12, 20), cadence: .semiMonthly)
        #expect(cal.component(.year, from: next) == 2027)
        #expect(cal.isDate(next, inSameDayAs: date(2027, 1, 1)))
    }

    // MARK: - currentPayPeriod / daysUntilNextPay (relative to "today")

    @Test
    func currentPayPeriodWeeklyAnchoredOneWeekOut() {
        let today = cal.startOfDay(for: Date())
        let nextPayDate = cal.date(byAdding: .day, value: 7, to: today)!

        let period = PayPeriodCalculator.currentPayPeriod(nextPayDate: nextPayDate, cadence: .weekly)

        #expect(cal.isDate(period.start, inSameDayAs: today))
        let expectedEndDay = cal.date(byAdding: .day, value: 6, to: today)!
        #expect(cal.isDate(period.end, inSameDayAs: expectedEndDay))
        #expect(cal.component(.hour, from: period.end) == 23)
    }

    @Test
    func daysUntilNextPayWeeklyAnchoredOneWeekOut() {
        let today = cal.startOfDay(for: Date())
        let nextPayDate = cal.date(byAdding: .day, value: 7, to: today)!

        let days = PayPeriodCalculator.daysUntilNextPay(nextPayDate: nextPayDate, cadence: .weekly)
        #expect(days == 7)
    }

    @Test
    func daysUntilNextPayIsNeverNegativeWhenNextPayDateIsInThePast() {
        let today = cal.startOfDay(for: Date())
        let staleNextPayDate = cal.date(byAdding: .day, value: -100, to: today)!

        let days = PayPeriodCalculator.daysUntilNextPay(nextPayDate: staleNextPayDate, cadence: .biweekly)
        #expect(days >= 0)
    }

    // MARK: - previousPayPeriods

    @Test
    func previousPayPeriodsAreConsecutiveAndOldestFirst() {
        let today = cal.startOfDay(for: Date())
        let nextPayDate = cal.date(byAdding: .day, value: 14, to: today)!

        let periods = PayPeriodCalculator.previousPayPeriods(nextPayDate: nextPayDate, cadence: .biweekly, count: 3)

        #expect(periods.count == 3)
        for index in 1..<periods.count {
            let previousEnd = periods[index - 1].end
            let expectedNextStart = previousEnd.addingTimeInterval(1)
            #expect(periods[index].start == expectedNextStart)
        }
        // None of the returned periods should reach into the current (not-yet-closed) period.
        let current = PayPeriodCalculator.currentPayPeriod(nextPayDate: nextPayDate, cadence: .biweekly)
        #expect(periods.last!.end < current.start)
    }

    // MARK: - calendarMonths

    @Test
    func calendarMonthsReturnsRequestedCountEndingWithCurrentMonth() {
        let months = PayPeriodCalculator.calendarMonths(count: 3)
        #expect(months.count == 3)

        let now = Date()
        let currentMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        #expect(cal.isDate(months.last!.start, inSameDayAs: currentMonthStart))

        for month in months {
            #expect(cal.component(.day, from: month.start) == 1)
            #expect(month.end > month.start)
        }
    }
}
