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
        let today = Date()

        // Walk back to find the most recent pay date on or before today
        var periodStart = nextPayDate
        while periodStart > today {
            periodStart = previousPayDate(before: periodStart, cadence: cadence)
        }

        let periodEnd = nextDate(after: periodStart, cadence: cadence, calendar: cal)
            .addingTimeInterval(-1) // end of previous day

        return PayPeriod(start: periodStart, end: periodEnd)
    }

    static func nextPayDate(after date: Date, cadence: PayCadence) -> Date {
        nextDate(after: date, cadence: cadence, calendar: Calendar.current)
    }

    static func daysUntilNextPay(nextPayDate: Date, cadence: PayCadence) -> Int {
        let period = currentPayPeriod(nextPayDate: nextPayDate, cadence: cadence)
        let cal = Calendar.current
        // The actual next pay is period.end + 1 second
        let next = period.end.addingTimeInterval(1)
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: next))
        return max(0, diff.day ?? 0)
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
