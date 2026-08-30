import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Category> { $0.typeRaw == "spending" }, sort: \Category.name)
    private var categories: [Category]
    @Query private var allTransactions: [Transaction]

    var remaining: Double?
    var editingTransaction: Transaction?

    init(remaining: Double? = nil, editingTransaction: Transaction? = nil) {
        self.remaining = remaining
        self.editingTransaction = editingTransaction
    }

    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var showFullCategoryGrid: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var showReceiptSheet: Bool = false
    @State private var receiptImageData: Data?
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    amountSection
                    categoryChips
                    detailControls
                    noteField
                    numericKeypad
                    saveButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Color.paper)
            .toolbar(.hidden, for: .navigationBar)
            .tint(.money)
            .safeAreaInset(edge: .top) {
                modalHeader
            }
            .onAppear { loadEditingTransaction() }
            .sheet(isPresented: $showFullCategoryGrid) {
                FullCategoryGridSheet(categories: categories, selectedCategory: $selectedCategory)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(date: $date)
            }
            .sheet(isPresented: $showReceiptSheet) {
                NavigationStack {
                    ScrollView {
                        ReceiptCaptureView(imageData: $receiptImageData)
                            .padding()
                    }
                    .navigationTitle("Receipt")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showReceiptSheet = false }
                        }
                    }
                }
            }
        }
    }

    private var canSave: Bool {
        guard let value = Double(amountText), value > 0 else { return false }
        return selectedCategory != nil
    }

    // MARK: - Modal header

    private var modalHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Circle()
                    .fill(Color.fill)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.inkSecondary)
                    )
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text(editingTransaction == nil ? "New expense" : "Edit expense")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.paper)
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(spacing: 6) {
            amountText.isEmpty
                ? Text("$0").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(Color.inkQuaternary)
                : styledAmount

            if let remaining {
                Text("\(remaining, format: .currency(code: "USD").precision(.fractionLength(0))) left this period")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkTertiary)
            }
        }
        .padding(.top, 8)
    }

    private var styledAmount: Text {
        let parts = amountText.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let dollars = String(parts.first ?? "")
        let cents = parts.count > 1 ? "." + parts[1] : ""
        return Text("$\(dollars)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(Color.ink)
            + Text(cents).font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(Color.inkQuaternary)
    }

    // MARK: - Category chips

    private var topCategories: [Category] {
        var counts: [ObjectIdentifier: Int] = [:]
        for t in allTransactions {
            guard let category = t.category else { continue }
            counts[ObjectIdentifier(category), default: 0] += 1
        }
        let sorted = categories.sorted { (counts[ObjectIdentifier($0)] ?? 0) > (counts[ObjectIdentifier($1)] ?? 0) }
        return Array(sorted.prefix(3))
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(topCategories) { category in
                    CategoryChip(category: category, isSelected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }

                Button {
                    showFullCategoryGrid = true
                } label: {
                    HStack(spacing: 6) {
                        if let selectedCategory, !topCategories.contains(selectedCategory) {
                            Image(systemName: selectedCategory.icon)
                            Text(selectedCategory.name)
                        } else {
                            Image(systemName: "square.grid.2x2.fill")
                            Text("More")
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Capsule().fill(Color.card))
                    .overlay(Capsule().strokeBorder(Color.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Detail controls

    private var detailControls: some View {
        HStack(spacing: 10) {
            Button {
                showDatePicker = true
            } label: {
                detailControlLabel(icon: "calendar", text: dateLabel, color: .inkSecondary)
            }

            Button {
                showReceiptSheet = true
            } label: {
                detailControlLabel(icon: "camera", text: receiptImageData == nil ? "Receipt" : "Receipt ✓", color: .inkTertiary)
            }
        }
    }

    private func detailControlLabel(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .background(Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.cardBorder, lineWidth: 1)
        )
    }

    private var dateLabel: String {
        Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var noteField: some View {
        TextField("Add a note", text: $note)
            .font(.system(size: 14))
            .foregroundStyle(Color.ink)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
            .focused($noteFieldFocused)
            .submitLabel(.done)
            .onSubmit { noteFieldFocused = false }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        noteFieldFocused = false
                    } label: {
                        Label("Hide Keyboard", systemImage: "keyboard.chevron.compact.down")
                    }
                }
            }
    }

    // MARK: - Keypad

    private var numericKeypad: some View {
        let rows: [[String]] = [
            ["1", "2", "3"],
            ["4", "5", "6"],
            ["7", "8", "9"],
            [".", "0", "delete.left"]
        ]
        return VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        KeypadKey(key: key) { handleKey(key) }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        switch key {
        case "delete.left":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") { amountText.append(".") }
        default:
            amountText.append(key)
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text(editingTransaction == nil ? "Save expense" : "Save changes")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.moneyFill)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.moneyFill.opacity(0.28), radius: 10, y: 8)
        }
        .opacity(canSave ? 1 : 0.4)
        .disabled(!canSave)
    }

    private func loadEditingTransaction() {
        if let editingTransaction {
            amountText = String(format: "%.2f", editingTransaction.amount)
            selectedCategory = editingTransaction.category
            date = editingTransaction.date
            note = editingTransaction.note ?? ""
            receiptImageData = editingTransaction.receiptImageData
        }
    }

    private func save() {
        guard let amount = Double(amountText), let category = selectedCategory else { return }

        if let editingTransaction {
            editingTransaction.amount = amount
            editingTransaction.category = category
            editingTransaction.date = date
            editingTransaction.note = note.isEmpty ? nil : note
            editingTransaction.receiptImageData = receiptImageData
        } else {
            let transaction = Transaction(amount: amount, date: date, note: note.isEmpty ? nil : note, category: category, receiptImageData: receiptImageData)
            modelContext.insert(transaction)
            AnalyticsService.transactionLogged()
        }

        try? modelContext.save()
        dismiss()
    }
}

private struct KeypadKey: View {
    let key: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if key == "delete.left" {
                    Image(systemName: key)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                } else {
                    Text(key)
                        .font(.system(size: 26, weight: .medium).monospacedDigit())
                        .foregroundStyle(Color.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.name)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? .white : Color.inkSecondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(isSelected ? Color.money : Color.card))
            .overlay(
                Capsule().strokeBorder(isSelected ? .clear : Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct FullCategoryGridSheet: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                    ForEach(categories) { category in
                        CategoryTile(category: category, isSelected: selectedCategory == category) {
                            selectedCategory = category
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .background(Color.paper)
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct DatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.money)
                .padding()
                .navigationTitle("Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium])
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
                        .stroke(Color.money, lineWidth: isSelected ? 3 : 0)
                        .padding(-3)
                )

                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}
