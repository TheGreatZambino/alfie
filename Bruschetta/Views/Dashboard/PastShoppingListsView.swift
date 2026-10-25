import SwiftUI
import SwiftData

/// Browse shopping trips that were logged as expenses.
struct PastShoppingListsView: View {
    @Query(filter: #Predicate<ShoppingItem> { $0.transaction != nil })
    private var purchased: [ShoppingItem]

    private var trips: [Transaction] {
        var seen = Set<PersistentIdentifier>()
        return purchased.compactMap(\.transaction)
            .filter { seen.insert($0.persistentModelID).inserted }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if trips.isEmpty {
                Text("No past lists yet. When you log a purchase from your cart, it shows up here.")
                    .font(.subheadline)
                    .foregroundStyle(Color.inkTertiary)
            }
            ForEach(trips) { trip in
                NavigationLink {
                    PastShoppingListDetailView(trip: trip)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                                .font(.rowTitle)
                                .foregroundStyle(Color.ink)
                            Text("\((trip.shoppingItems ?? []).count) items" + (trip.category.map { " · \($0.name)" } ?? ""))
                                .font(.rowDetail)
                                .foregroundStyle(Color.inkTertiary)
                        }
                        Spacer()
                        Text(trip.amount, format: .currency(code: "USD"))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                    }
                }
            }
        }
        .alfieListStyle()
        .navigationTitle("Past lists")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.money)
    }
}

private struct PastShoppingListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let trip: Transaction

    @State private var templateName = ""
    @State private var showSaveTemplate = false
    @State private var didAdd = false

    private var items: [ShoppingItem] {
        (trip.shoppingItems ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    HStack {
                        Text(item.name)
                            .font(.rowTitle)
                            .foregroundStyle(Color.ink)
                        Spacer()
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("\(items.count) items")
                    Spacer()
                    Text(trip.amount, format: .currency(code: "USD"))
                }
            }

            Section {
                Button {
                    for item in items {
                        modelContext.insert(ShoppingItem(name: item.name, quantity: item.quantity, estimatedPrice: item.estimatedPrice))
                    }
                    try? modelContext.save()
                    didAdd = true
                } label: {
                    Label(didAdd ? "Added to your list" : "Add all to current list", systemImage: didAdd ? "checkmark" : "cart.badge.plus")
                }
                .disabled(didAdd)

                Button {
                    templateName = ""
                    showSaveTemplate = true
                } label: {
                    Label("Save as list…", systemImage: "square.and.arrow.down")
                }
            }
        }
        .alfieListStyle()
        .navigationTitle(trip.date.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save as list", isPresented: $showSaveTemplate) {
            TextField("List name", text: $templateName)
            Button("Save", action: saveTemplate)
            Button("Cancel", role: .cancel) {}
        }
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
}
