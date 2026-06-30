import Foundation
import SwiftData
import Combine

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var filterCategory: Category? = nil
    @Published var filterStartDate: Date? = nil
    @Published var filterEndDate: Date? = nil

    func filtered(_ transactions: [Transaction]) -> [Transaction] {
        transactions.filter { t in
            if let filterCategory, t.category !== filterCategory { return false }
            if let filterStartDate, t.date < filterStartDate { return false }
            if let filterEndDate, t.date > filterEndDate { return false }
            return true
        }
    }

    func groupedByDate(_ transactions: [Transaction]) -> [(label: String, items: [Transaction])] {
        let cal = Calendar.current
        let sorted = transactions.sorted { $0.date > $1.date }
        var groups: [String: [Transaction]] = [:]
        var order: [String] = []

        for t in sorted {
            let label: String
            if cal.isDateInToday(t.date) {
                label = "Today"
            } else if cal.isDateInYesterday(t.date) {
                label = "Yesterday"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                label = formatter.string(from: t.date)
            }
            if groups[label] == nil {
                groups[label] = []
                order.append(label)
            }
            groups[label]?.append(t)
        }

        return order.map { (label: $0, items: groups[$0] ?? []) }
    }

    func clearFilters() {
        filterCategory = nil
        filterStartDate = nil
        filterEndDate = nil
    }
}
