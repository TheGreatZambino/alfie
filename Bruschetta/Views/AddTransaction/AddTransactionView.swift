import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.typeRaw == "spending" }, sort: \Category.sortOrder)
    private var categories: [Category]

    var editingTransaction: Transaction?

    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var date: Date = Date()
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                amountField

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        categoryGrid

                        DatePicker("Date", selection: $date, displayedComponents: .date)
                            .padding(.horizontal)

                        TextField("Note (optional)", text: $note)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(editingTransaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { loadEditingTransaction() }
        }
    }

    private var canSave: Bool {
        guard let value = Double(amountText), value > 0 else { return false }
        return selectedCategory != nil
    }

    private var amountField: some View {
        VStack(spacing: 8) {
            Text(amountText.isEmpty ? "$0.00" : "$\(amountText)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(amountText.isEmpty ? .secondary : .primary)
                .padding(.top, 12)

            numericKeypad
        }
        .padding(.bottom, 12)
        .background(Color(.secondarySystemBackground))
    }

    private var numericKeypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "⌫"]
        ]
        return VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") { amountText.append(".") }
        default:
            amountText.append(key)
        }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(categories) { category in
                    CategoryTile(category: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func loadEditingTransaction() {
        guard let editingTransaction else { return }
        amountText = String(format: "%.2f", editingTransaction.amount)
        selectedCategory = editingTransaction.category
        date = editingTransaction.date
        note = editingTransaction.note ?? ""
    }

    private func save() {
        guard let amount = Double(amountText), let category = selectedCategory else { return }

        if let editingTransaction {
            editingTransaction.amount = amount
            editingTransaction.category = category
            editingTransaction.date = date
            editingTransaction.note = note.isEmpty ? nil : note
        } else {
            let transaction = Transaction(amount: amount, date: date, note: note.isEmpty ? nil : note, category: category)
            modelContext.insert(transaction)
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct CategoryTile: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.icon)
                        .foregroundStyle(.white)
                        .font(.title3)
                }
                .overlay(
                    Circle()
                        .stroke(Color.appAccent, lineWidth: isSelected ? 3 : 0)
                        .padding(-3)
                )

                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
