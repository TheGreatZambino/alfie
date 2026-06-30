import SwiftUI
import SwiftData

struct CategoriesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    @State private var showAddCategory = false
    @State private var editingCategory: Category?
    @State private var showDeleteAlert = false
    @State private var categoryPendingDelete: Category?

    var body: some View {
        List {
            ForEach(categories) { category in
                Button {
                    editingCategory = category
                } label: {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color(hex: category.colorHex))
                                .frame(width: 32, height: 32)
                            Image(systemName: category.icon)
                                .foregroundStyle(.white)
                                .font(.caption)
                        }
                        Text(category.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(category.type == .bill ? "Bill" : "Spending")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: requestDelete)
            .onMove(perform: moveCategories)
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryEditView(category: nil)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditView(category: category)
        }
        .alert("Cannot Delete Category", isPresented: $showDeleteAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This category has existing transactions and cannot be deleted.")
        }
    }

    private func requestDelete(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            if let transactions = category.transactions, !transactions.isEmpty {
                categoryPendingDelete = category
                showDeleteAlert = true
            } else {
                modelContext.delete(category)
            }
        }
        try? modelContext.save()
    }

    private func moveCategories(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct CategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingCategories: [Category]

    let category: Category?

    @State private var name: String = ""
    @State private var icon: String = "tag.fill"
    @State private var colorHex: String = "#0D7377"
    @State private var type: CategoryType = .spending

    private let iconOptions = ["tag.fill", "cart.fill", "fork.knife", "fuelpump.fill", "wrench.and.screwdriver.fill", "tv.fill", "bag.fill", "cross.case.fill", "repeat.circle.fill", "house.fill", "car.fill", "airplane", "gift.fill", "pawprint.fill", "book.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $type) {
                        Text("Spending").tag(CategoryType.spending)
                        Text("Bill").tag(CategoryType.bill)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { option in
                            Image(systemName: option)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(icon == option ? Color.appAccent.opacity(0.2) : Color(.tertiarySystemBackground))
                                .clipShape(Circle())
                                .onTapGesture { icon = option }
                        }
                    }
                }

                Section("Color") {
                    ColorPicker("Category Color", selection: Binding(
                        get: { Color(hex: colorHex) },
                        set: { newColor in colorHex = newColor.toHex() }
                    ))
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .onAppear { load() }
        }
    }

    private func load() {
        guard let category else { return }
        name = category.name
        icon = category.icon
        colorHex = category.colorHex
        type = category.type
    }

    private func save() {
        if let category {
            category.name = name
            category.icon = icon
            category.colorHex = colorHex
            category.type = type
        } else {
            let sortOrder = (existingCategories.map(\.sortOrder).max() ?? -1) + 1
            let newCategory = Category(name: name, icon: icon, colorHex: colorHex, type: type, sortOrder: sortOrder)
            modelContext.insert(newCategory)
        }
        try? modelContext.save()
        dismiss()
    }
}
