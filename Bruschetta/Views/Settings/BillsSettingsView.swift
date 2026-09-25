import SwiftUI
import SwiftData

struct BillsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bill.name) private var bills: [Bill]

    @State private var showAddBill = false
    @State private var editingBill: Bill?

    var body: some View {
        List {
            ForEach(bills) { bill in
                Button {
                    editingBill = bill
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(bill.name)
                                .foregroundStyle(.primary)
                            Text("Due date \(bill.dueDay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bill.amount, format: .currency(code: "USD"))
                            .foregroundStyle(.primary)
                        Toggle("", isOn: Binding(
                            get: { bill.isActive },
                            set: { newValue in
                                bill.isActive = newValue
                                try? modelContext.save()
                            }
                        ))
                        .labelsHidden()
                    }
                }
            }
            .onDelete(perform: deleteBills)
        }
        .navigationTitle("Bills")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddBill) {
            BillEditView(bill: nil)
        }
        .sheet(item: $editingBill) { bill in
            BillEditView(bill: bill)
        }
    }

    private func deleteBills(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(bills[index])
        }
        try? modelContext.save()
    }
}

private struct BillEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    let bill: Bill?

    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var allocationAmountText: String = ""
    @State private var dueDay: Int = 1
    @State private var showDueDatePicker = false
    @State private var category: Category?
    @State private var isActive: Bool = true
    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    private var availableCategories: [Category] {
        categories
            .filter { !$0.isSavingsOrInvesting || $0 === category }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    CurrencyTextField(placeholder: "Total Amount", text: $amountText)
                    CurrencyTextField(placeholder: "Allocate per Paycheck", text: $allocationAmountText)
                    Button {
                        showDueDatePicker = true
                    } label: {
                        HStack {
                            Text("Due date")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(ordinalDayLabel(dueDay))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .sheet(isPresented: $showDueDatePicker) {
                        DueDayPickerView(selectedDay: $dueDay)
                    }
                    Picker("Category", selection: $category) {
                        Text("None").tag(Category?.none)
                        ForEach(availableCategories) { cat in
                            Text(cat.name).tag(Category?.some(cat))
                        }
                    }
                    Toggle("Active", isOn: $isActive)
                } header: {
                    Text("Details")
                } footer: {
                    Text("Total Amount is the actual bill cost. Allocate per Paycheck is what you set aside each pay period — it can be more than the minimum required. For savings or investing contributions, use Settings > Savings & investments instead — those aren't due on a specific day.")
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes)
                }

                if bill != nil {
                    Section {
                        Button("Delete Bill", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(bill == nil ? "Add Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this bill?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Bill", role: .destructive) { delete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || Double(amountText) == nil)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let bill else { return }
        name = bill.name
        amountText = String(format: "%.2f", bill.amount)
        allocationAmountText = String(format: "%.2f", bill.allocationAmount)
        dueDay = bill.dueDay
        category = bill.category
        isActive = bill.isActive
        notes = bill.notes ?? ""
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        let allocationAmount = Double(allocationAmountText) ?? amount
        if let bill {
            bill.name = name
            bill.amount = amount
            bill.allocationAmount = allocationAmount
            bill.dueDay = dueDay
            bill.category = category
            bill.isActive = isActive
            bill.notes = notes.isEmpty ? nil : notes
        } else {
            let newBill = Bill(name: name, amount: amount, allocationAmount: allocationAmount, dueDay: dueDay, category: category, isActive: isActive, notes: notes.isEmpty ? nil : notes)
            modelContext.insert(newBill)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let bill else { return }
        modelContext.delete(bill)
        try? modelContext.save()
        dismiss()
    }

    private func ordinalDayLabel(_ day: Int) -> String {
        let suffix: String
        switch day {
        case 11, 12, 13: suffix = "th"
        default:
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(day)\(suffix)"
    }
}

private struct DueDayPickerView: View {
    @Binding var selectedDay: Int
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    /// Uses the current month's layout purely for a familiar calendar grid; the value stored is just a day-of-month (1-31), not a specific date.
    private var leadingBlankCount: Int {
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let firstOfMonth = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<leadingBlankCount, id: \.self) { _ in
                        Color.clear.frame(height: 40)
                    }
                    ForEach(1...31, id: \.self) { day in
                        Button {
                            selectedDay = day
                            dismiss()
                        } label: {
                            Text("\(day)")
                                .font(.body)
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(day == selectedDay ? Color.accentColor : Color.clear)
                                )
                                .foregroundStyle(day == selectedDay ? Color.white : Color.primary)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
