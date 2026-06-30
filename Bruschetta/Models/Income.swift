import Foundation
import SwiftData

@Model
final class Income {
    var amount: Double = 0
    var payCadence: String = PayCadence.biweekly.rawValue
    var nextPayDate: Date = Date()

    init(amount: Double, payCadence: PayCadence, nextPayDate: Date) {
        self.amount = amount
        self.payCadence = payCadence.rawValue
        self.nextPayDate = nextPayDate
    }

    var cadence: PayCadence {
        get { PayCadence(rawValue: payCadence) ?? .biweekly }
        set { payCadence = newValue.rawValue }
    }

    var amountPerPeriod: Double {
        amount
    }

    func nextPayDate(after date: Date) -> Date {
        PayPeriodCalculator.nextPayDate(after: date, cadence: cadence)
    }

    var currentPayPeriod: PayPeriod {
        PayPeriodCalculator.currentPayPeriod(nextPayDate: nextPayDate, cadence: cadence)
    }
}
