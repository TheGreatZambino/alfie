import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<ShoppingItem> { $0.transaction == nil }, sort: \ShoppingItem.createdAt)
    private var items: [ShoppingItem]
    @Query(sort: \ShoppingListTemplate.name) private var templates: [ShoppingListTemplate]

    @State private var newName = ""
    @State private var editingItem: ShoppingItem?
    @State private var showTemplates = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var showLogPurchase = false
    @State private var showClearConfirmation = false
    @FocusState private var addFieldFocused: Bool

    private var toBuy: [ShoppingItem] { items.filter { !$0.isChecked } }
    private var inCart: [ShoppingItem] { items.filter { $0.isChecked } }
    private func total(_ list: [ShoppingItem]) -> Double { list.reduce(0) { $0 + $1.estimatedTotal } }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.money)
                    TextField("Add an item", text: $newName)
                        .focused($addFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                }
            }

            if !toBuy.isEmpty {
                Section {
                    ForEach(toBuy) { row($0) }
                } header: {
                    HStack {
                        Text("To buy")
                        Spacer()
                        if total(toBuy) > 0 {
                            Text("≈ \(total(toBuy), format: .currency(code: "USD"))")
                        }
                    }
                }
            }

            if !inCart.isEmpty {
                Section {
                    ForEach(inCart) { row($0) }
                } header: {
                    HStack {
                        Text("In cart")
                        Spacer()
                        if total(inCart) > 0 {
                            Text("≈ \(total(inCart), format: .currency(code: "USD"))")
                        }
                    }
                } footer: {
                    Button {
                        showLogPurchase = true
                    } label: {
                        Label("Log purchase as expense", systemImage: "creditcard.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.moneyFill)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 12)
                }
            }

            if items.isEmpty {
                Section {
                    Text("Your list is empty. Add items above, or start from a saved list.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
        .alfieListStyle()
        .navigationTitle("Shopping List")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.money)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showTemplates = true } label: {
                        Label("Add from saved list", systemImage: "list.bullet.rectangle")
                    }
                    Button {
                        templateName = ""
                        showSaveTemplate = true
                    } label: {
                        Label("Save as list…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(items.isEmpty)
                    NavigationLink {
                        PastShoppingListsView()
                    } label: {
                        Label("Past lists", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button(role: .destructive) { showClearConfirmation = true } label: {
                        Label("Clear list", systemImage: "trash")
                    }
                    .disabled(items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Save as list", isPresented: $showSaveTemplate) {
            TextField("List name", text: $templateName)
            Button("Save", action: saveTemplate)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Save these items so you can re-use them next time.")
        }
        .confirmationDialog("Remove every item from the list?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("Clear list", role: .destructive) {
                withAnimation { items.forEach(modelContext.delete) }
            }
        }
        .sheet(item: $editingItem) { EditShoppingItemView(item: $0) }
        .sheet(isPresented: $showTemplates) {
            ShoppingTemplatesSheet(templates: templates) { template in
                add(from: template)
            }
        }
        .sheet(isPresented: $showLogPurchase) {
            LogShoppingPurchaseView(items: inCart)
        }
    }

    private func row(_ item: ShoppingItem) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { item.isChecked.toggle() }
            } label: {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isChecked ? Color.money : Color.inkTertiary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.rowTitle)
                    .foregroundStyle(item.isChecked ? Color.inkTertiary : Color.ink)
                    .strikethrough(item.isChecked)
                if item.estimatedPrice > 0 {
                    Text("\(item.estimatedPrice, format: .currency(code: "USD")) each")
                        .font(.rowDetail)
                        .foregroundStyle(Color.inkTertiary)
                }
            }

            Spacer()

            if item.quantity > 1 {
                Text("×\(item.quantity)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingItem = item }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                withAnimation { modelContext.delete(item) }
            } label: {
                Label("Remove", systemImage: "xmark.bin")
            }
        }
        .contextMenu {
            Button("Edit") { editingItem = item }
            Button("Remove from list", role: .destructive) {
                withAnimation { modelContext.delete(item) }
            }
        }
    }

    private func addItem() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        withAnimation { modelContext.insert(ShoppingItem(name: name)) }
        newName = ""
        addFieldFocused = true
    }

    private func saveTemplate() {
        let name = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let template = ShoppingListTemplate(name: name)
        modelContext.insert(template)
        for (index, item) in items.enumerated() {
            let entry = ShoppingTemplateItem(name: item.name, quantity: item.quantity, estimatedPrice: item.estimatedPrice, sortOrder: index)
            modelContext.insert(entry)
            entry.template = template
        }
        try? modelContext.save()
    }

    private func add(from template: ShoppingListTemplate) {
        for entry in template.sortedItems {
            modelContext.insert(ShoppingItem(name: entry.name, quantity: entry.quantity, estimatedPrice: entry.estimatedPrice))
        }
        try? modelContext.save()
    }
}

// MARK: - Edit item

private struct EditShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: ShoppingItem

    @State private var name = ""
    @State private var quantity = 1
    @State private var priceText = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)
                HStack {
                    Text("Price each")
                    Spacer()
                    TextField("0.00", text: $priceText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Section {
                    Button("Remove from list", role: .destructive) {
                        modelContext.delete(item)
                        dismiss()
                    }
                }
            }
            .alfieListStyle()
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { item.name = trimmed }
                        item.quantity = quantity
                        item.estimatedPrice = Double(priceText) ?? 0
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = item.name
                quantity = item.quantity
                priceText = item.estimatedPrice > 0 ? String(format: "%.2f", item.estimatedPrice) : ""
            }
        }
        .presentationDetents([.medium])
        .tint(.money)
    }
}

// MARK: - Saved lists

private struct ShoppingTemplatesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let templates: [ShoppingListTemplate]
    let onSelect: (ShoppingListTemplate) -> Void

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Text("No saved lists yet. Use “Save as list…” to keep the current list for next time.")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkTertiary)
                }
                ForEach(templates) { template in
                    Button {
                        onSelect(template)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .font(.rowTitle)
                                .foregroundStyle(Color.ink)
                            Text(summary(template))
                                .font(.rowDetail)
                                .foregroundStyle(Color.inkTertiary)
                                .lineLimit(2)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(templates[index]) }
                }
            }
            .alfieListStyle()
            .navigationTitle("Saved lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .tint(.money)
    }

    private func summary(_ template: ShoppingListTemplate) -> String {
        let names = template.sortedItems.map(\.name)
        guard !names.isEmpty else { return "Empty" }
        return "\(names.count) items · " + names.joined(separator: ", ")
    }
}

// MARK: - Log purchase

private struct LogShoppingPurchaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.name) private var categories: [Category]
    let items: [ShoppingItem]

    @State private var amountText = ""
    @State private var category: Category?
    @State private var date = Date()

    private var amount: Double? { Double(amountText).flatMap { $0 > 0 ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Total spent") {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Section {
                    Picker("Category", selection: $category) {
                        Text("Choose…").tag(Category?.none)
                        ForEach(categories) { Label($0.name, systemImage: $0.icon).tag(Optional($0)) }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("\(items.count) items") {
                    ForEach(items) { item in
                        HStack {
                            Text(item.name)
                            Spacer()
                            if item.quantity > 1 { Text("×\(item.quantity)").foregroundStyle(Color.inkTertiary) }
                        }
                    }
                }
            }
            .alfieListStyle()
            .navigationTitle("Log purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(amount == nil || category == nil)
                }
            }
            .onAppear {
                let estimate = items.reduce(0) { $0 + $1.estimatedTotal }
                if estimate > 0 { amountText = String(format: "%.2f", estimate) }
                category = categories.first { $0.name.localizedCaseInsensitiveContains("grocer") }
            }
        }
        .tint(.money)
    }

    private func save() {
        guard let amount, let category else { return }
        let transaction = Transaction(amount: amount, date: date, note: "Shopping list (\(items.count) items)", category: category)
        modelContext.insert(transaction)
        for item in items { item.transaction = transaction }
        AnalyticsService.transactionLogged()
        try? modelContext.save()
        dismiss()
    }
}
