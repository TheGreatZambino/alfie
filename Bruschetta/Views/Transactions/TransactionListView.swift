import SwiftUI
import SwiftData
import Charts

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @StateObject private var viewModel = TransactionViewModel()
    @State private var showFilter = false
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?

    var body: some View {
        NavigationStack {
            List {
                let filtered = viewModel.filtered(transactions)
                if !filtered.isEmpty {
                    Section {
                        SpendingByCategoryCard(items: spendingByCategory(from: filtered))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(viewModel.groupedByDate(filtered), id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.items) { transaction in
                            TransactionRowView(transaction: transaction)
                                .contentShape(Rectangle())
                                .onTapGesture { editingTransaction = transaction }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(transaction)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTransaction = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilter = true } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView()
            }
            .sheet(isPresented: $showFilter) {
                TransactionFilterView(viewModel: viewModel, categories: categories)
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(editingTransaction: transaction)
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView("No Transactions", systemImage: "list.bullet", description: Text("Transactions you add will show up here."))
                }
            }
        }
    }

    private func delete(_ transaction: Transaction) {
        modelContext.delete(transaction)
        try? modelContext.save()
    }

    private func spendingByCategory(from txns: [Transaction]) -> [(category: Category, amount: Double)] {
        var grouped: [ObjectIdentifier: (category: Category, amount: Double)] = [:]
        for t in txns {
            guard let category = t.category else { continue }
            let key = ObjectIdentifier(category)
            grouped[key, default: (category, 0)].amount += t.amount
        }
        return grouped.values.sorted { $0.amount > $1.amount }
    }
}

private struct TransactionFilterView: View {
    @ObservedObject var viewModel: TransactionViewModel
    let categories: [Category]
    @Environment(\.dismiss) private var dismiss

    @State private var useDateRange = false
    @State private var startDate = Date()
    @State private var endDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $viewModel.filterCategory) {
                        Text("All").tag(Category?.none)
                        ForEach(categories) { category in
                            Text(category.name).tag(Category?.some(category))
                        }
                    }
                }

                Section("Date Range") {
                    Toggle("Filter by date range", isOn: $useDateRange)
                    if useDateRange {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        viewModel.clearFilters()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if useDateRange {
                            viewModel.filterStartDate = Calendar.current.startOfDay(for: startDate)
                            viewModel.filterEndDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate))
                        } else {
                            viewModel.filterStartDate = nil
                            viewModel.filterEndDate = nil
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
