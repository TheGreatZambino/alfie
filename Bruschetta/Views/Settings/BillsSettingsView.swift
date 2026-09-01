import SwiftUI
import SwiftData

struct BillsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bill.dueDay) private var bills: [Bill]

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
                            Text("Due day \(bill.dueDay)")
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
    @State private var dueDayText: String = "1"
    @State private var category: Category?
    @State private var isActive: Bool = true
    @State private var notes: String = ""

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
                    HStack {
                        Text("Due day")
                        Spacer()
                        SelectAllOnFocusTextField(placeholder: "Day", text: $dueDayText, keyboardType: .numberPad, textAlignment: .right)
                            .frame(width: 50)
                            .onChange(of: dueDayText) { _, newValue in
                                let clamped = min(max(Int(newValue) ?? 1, 1), 31)
                                dueDay = clamped
                                if newValue != String(clamped) {
                                    dueDayText = String(clamped)
                                }
                            }
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
            }
            .navigationTitle(bill == nil ? "Add Bill" : "Edit Bill")
            .navigationBarTitleDisplayMode(.inline)
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
        dueDayText = String(bill.dueDay)
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
}
