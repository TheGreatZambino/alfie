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
                        Toggle("", isOn: Binding(
                            get: { category.includeInOverview },
                            set: { newValue in
                                category.includeInOverview = newValue
                                try? modelContext.save()
                            }
                        ))
                        .labelsHidden()
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
    @State private var includeInOverview: Bool = true

    private let iconOptions = [
        // General
        "tag.fill", "star.fill", "flag.fill", "sparkles", "ellipsis.circle.fill",
        // Shopping & dining
        "cart.fill", "bag.fill", "basket.fill", "fork.knife", "cup.and.saucer.fill",
        "takeoutbag.and.cup.and.straw.fill", "wineglass.fill",
        // Home
        "house.fill", "bed.double.fill", "sofa.fill", "lightbulb.fill", "hammer.fill",
        "wrench.and.screwdriver.fill",
        // Transportation & travel
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill", "bicycle",
        "parkingsign.circle.fill", "airplane", "suitcase.fill", "beach.umbrella.fill", "globe",
        // Health & fitness
        "cross.case.fill", "heart.fill", "pills.fill", "stethoscope", "figure.walk",
        "figure.strengthtraining.traditional", "dumbbell.fill", "sportscourt.fill",
        // Entertainment & subscriptions
        "tv.fill", "gamecontroller.fill", "film.fill", "music.note", "theatermasks.fill",
        "repeat.circle.fill",
        // Finance & bills
        "creditcard.fill", "banknote.fill", "dollarsign.circle.fill", "chart.pie.fill",
        "building.columns.fill", "doc.text.fill", "shield.fill", "bolt.fill", "flame.fill",
        "drop.fill", "wifi", "phone.fill",
        // Family, pets & education
        "pawprint.fill", "teddybear.fill", "graduationcap.fill", "book.fill", "pencil",
        // Work & other
        "briefcase.fill", "gift.fill", "scissors",
    ]

    /// A varied pool of candidate colors to draw a non-colliding default from; falls back to a random hue if every candidate is already in use.
    private static let colorPalette: [String] = [
        "#0D7377", "#4CAF50", "#FF7043", "#FFA726", "#42A5F5", "#AB47BC",
        "#EC407A", "#26A69A", "#8D6E63", "#7E57C2", "#5C6BC0", "#29B6F6",
        "#66BB6A", "#FFCA28", "#EF5350"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                } header: {
                    Text("Details")
                }

                Section {
                    Toggle("Include in Overview", isOn: $includeInOverview)
                } footer: {
                    Text("Transactions in this category are always tracked. Turning this off just excludes them from Dashboard, Overview, and Trends totals.")
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(iconOptions, id: \.self) { option in
                            Image(systemName: option)
                                .font(.title3)
                                .frame(width: 44, height: 44)
                                .background(icon == option ? Color.money.opacity(0.2) : Color(.tertiarySystemBackground))
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
        guard let category else {
            colorHex = defaultUnusedColor()
            return
        }
        name = category.name
        icon = category.icon
        colorHex = category.colorHex
        includeInOverview = category.includeInOverview
    }

    private func defaultUnusedColor() -> String {
        let usedHexes = Set(existingCategories.map { $0.colorHex.uppercased() })
        if let unused = Self.colorPalette.first(where: { !usedHexes.contains($0.uppercased()) }) {
            return unused
        }
        return String(format: "#%06X", Int.random(in: 0...0xFFFFFF))
    }

    private func save() {
        if let category {
            category.name = name
            category.icon = icon
            category.colorHex = colorHex
            category.includeInOverview = includeInOverview
        } else {
            let sortOrder = (existingCategories.map(\.sortOrder).max() ?? -1) + 1
            let newCategory = Category(name: name, icon: icon, colorHex: colorHex, sortOrder: sortOrder)
            newCategory.includeInOverview = includeInOverview
            modelContext.insert(newCategory)
        }
        try? modelContext.save()
        dismiss()
    }
}
