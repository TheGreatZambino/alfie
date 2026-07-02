import Foundation

struct PayPeriod {
    let start: Date
    let end: Date

    func contains(day: Int) -> Bool {
        let cal = Calendar.current
        let startDay = cal.component(.day, from: start)
        let endDay = cal.component(.day, from: end)
        let startMonth = cal.component(.month, from: start)
        let endMonth = cal.component(.month, from: end)

        if startMonth == endMonth {
            return day >= startDay && day <= endDay
        } else {
            // Period crosses month boundary
            return day >= startDay || day <= endDay
        }
    }
}

enum PayPeriodCalculator {
    static func currentPayPeriod(nextPayDate: Date, cadence: PayCadence) -> PayPeriod {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Normalize to midnight so time-of-day in stored nextPayDate never affects comparisons
        var periodStart = cal.startOfDay(for: nextPayDate)
        while periodStart > today {
            periodStart = previousPayDate(before: periodStart, cadence: cadence)
        }

        // End of period = 23:59:59 on the day before the next pay date
        let nextPay = nextDate(after: periodStart, cadence: cadence, calendar: cal)
        let periodEndDay = cal.date(byAdding: .day, value: -1, to: nextPay) ?? nextPay
        let periodEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: periodEndDay) ?? periodEndDay

        return PayPeriod(start: periodStart, end: periodEnd)
    }

    static func nextPayDate(after date: Date, cadence: PayCadence) -> Date {
        nextDate(after: date, cadence: cadence, calendar: Calendar.current)
    }

    static func daysUntilNextPay(nextPayDate: Date, cadence: PayCadence) -> Int {
        let period = currentPayPeriod(nextPayDate: nextPayDate, cadence: cadence)
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // Next pay day is the day after the period ends
        let nextPay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: period.end)) ?? period.end
        let diff = cal.dateComponents([.day], from: today, to: nextPay)
        return max(0, diff.day ?? 0)
    }

    /// Returns the last `count` completed pay periods (oldest first), not including the current period.
    static func previousPayPeriods(nextPayDate: Date, cadence: PayCadence, count: Int) -> [PayPeriod] {
        let current = currentPayPeriod(nextPayDate: nextPayDate, cadence: cadence)
        var periods: [PayPeriod] = []
        var anchor = current.start
        for _ in 0 ..< count {
            let end = anchor.addingTimeInterval(-1)
            let start = previousPayDate(before: anchor, cadence: cadence)
            periods.append(PayPeriod(start: start, end: end))
            anchor = start
        }
        return periods.reversed()
    }

    /// Returns the last `count` calendar months (oldest first), including the current partial month.
    static func calendarMonths(count: Int) -> [PayPeriod] {
        let cal = Calendar.current
        let today = Date()
        var result: [PayPeriod] = []
        for offset in (0 ..< count).reversed() {
            guard
                let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: -offset, to: today)!)),
                let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart)
            else { continue }
            result.append(PayPeriod(start: monthStart, end: monthEnd))
        }
        return result
    }

    // MARK: - Private

    private static func nextDate(after date: Date, cadence: PayCadence, calendar: Calendar) -> Date {
        switch cadence {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date) ?? date
        case .semiMonthly:
            return nextSemiMonthly(after: date, calendar: calendar)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }

    private static func previousPayDate(before date: Date, cadence: PayCadence) -> Date {
        let cal = Calendar.current
        switch cadence {
        case .weekly:
            return cal.date(byAdding: .day, value: -7, to: date) ?? date
        case .biweekly:
            return cal.date(byAdding: .day, value: -14, to: date) ?? date
        case .semiMonthly:
            return prevSemiMonthly(before: date, calendar: cal)
        case .monthly:
            return cal.date(byAdding: .month, value: -1, to: date) ?? date
        }
    }

    private static func nextSemiMonthly(after date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        let day = comps.day ?? 1
        if day < 15 {
            comps.day = 15
            return calendar.date(from: comps) ?? date
        } else {
            // Move to 1st of next month
            comps.day = 1
            comps.month = (comps.month ?? 1) + 1
            if (comps.month ?? 1) > 12 {
                comps.month = 1
                comps.year = (comps.year ?? 2024) + 1
            }
            return calendar.date(from: comps) ?? date
        }
    }

    private static func prevSemiMonthly(before date: Date, calendar: Calendar) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        let day = comps.day ?? 1
        if day >= 15 {
            comps.day = 1
            return calendar.date(from: comps) ?? date
        } else {
            // Move to 15th of previous month
            comps.day = 15
            comps.month = (comps.month ?? 2) - 1
            if (comps.month ?? 0) < 1 {
                comps.month = 12
                comps.year = (comps.year ?? 2024) - 1
            }
            return calendar.date(from: comps) ?? date
        }
    }
}
