import SwiftUI
import SwiftData

struct AddFoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var localFoodItems: [FoodItem]
    @Query(sort: \NutritionEntry.date, order: .reverse) private var allEntries: [NutritionEntry]

    @ObservedObject private var lookupService = FoodLookupService.shared

    @State private var query: String = ""
    @State private var networkResults: [FoodResult] = []
    @State private var selectedResult: FoodResult?
    @State private var selectedLocalItem: FoodItem?
    @State private var showCustomForm = false

    private let prefillResult: FoodResult?
    private let unmatchedBarcode: String?
    private let defaultMealType: MealType?
    private let existingEntry: NutritionEntry?

    init(prefillResult: FoodResult? = nil, unmatchedBarcode: String? = nil, defaultMealType: MealType? = nil, existingEntry: NutritionEntry? = nil) {
        self.prefillResult = prefillResult
        self.unmatchedBarcode = unmatchedBarcode
        self.defaultMealType = defaultMealType
        self.existingEntry = existingEntry
    }

    var body: some View {
        NavigationStack {
            List {
                if let unmatchedBarcode, query.isEmpty {
                    Section {
                        Text("No product found for barcode \(unmatchedBarcode). Search for it below or add it as a custom food.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !matchingLocalItems.isEmpty {
                    Section("Your Foods") {
                        ForEach(matchingLocalItems) { item in
                            Button {
                                selectedLocalItem = item
                            } label: {
                                resultRow(name: item.name, brand: item.brand, calories: item.calories, servingDescription: item.servingDescription)
                            }
                        }
                    }
                }

                if query.isEmpty && !recentFoodItems.isEmpty {
                    Section("Recent") {
                        ForEach(recentFoodItems) { item in
                            Button {
                                selectedLocalItem = item
                            } label: {
                                resultRow(name: item.name, brand: item.brand, calories: item.calories, servingDescription: item.servingDescription)
                            }
                        }
                    }
                }

                if !networkResults.isEmpty {
                    Section("Search Results") {
                        ForEach(networkResults) { result in
                            Button {
                                selectedResult = result
                            } label: {
                                resultRow(name: result.name, brand: result.brand, calories: result.calories, servingDescription: result.servingDescription)
                            }
                        }
                    }
                } else if lookupService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if let error = lookupService.errorMessage, !query.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        showCustomForm = true
                    } label: {
                        Label("Create Custom Food", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $query, prompt: "Search foods, e.g. chicken breast")
            .task(id: query) {
                guard !query.isEmpty else {
                    networkResults = []
                    return
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                networkResults = await lookupService.search(query: query)
            }
            .navigationTitle(existingEntry != nil ? "Edit Food" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedResult) { result in
                LogFoodDetailView(result: result, defaultMealType: defaultMealType, existingEntry: existingEntry) { dismiss() }
            }
            .sheet(item: $selectedLocalItem) { item in
                LogFoodDetailView(foodItem: item, defaultMealType: defaultMealType, existingEntry: existingEntry) { dismiss() }
            }
            .sheet(isPresented: $showCustomForm) {
                CustomFoodFormView(barcode: prefillResult?.barcode ?? unmatchedBarcode, defaultMealType: defaultMealType, existingEntry: existingEntry) { dismiss() }
            }
            .onAppear {
                if let prefillResult {
                    selectedResult = prefillResult
                } else if let existingEntry, let foodItem = existingEntry.foodItem {
                    selectedLocalItem = foodItem
                }
            }
        }
    }

    private var matchingLocalItems: [FoodItem] {
        guard !query.isEmpty else { return [] }
        return localFoodItems.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Distinct foods from the user's logging history, most recent first — backs the
    /// Nutrition tab's "Recent" quick-log entry point.
    private var recentFoodItems: [FoodItem] {
        var seen = Set<PersistentIdentifier>()
        var items: [FoodItem] = []
        for entry in allEntries {
            guard let item = entry.foodItem, !seen.contains(item.id) else { continue }
            seen.insert(item.id)
            items.append(item)
            if items.count == 8 { break }
        }
        return items
    }

    private func resultRow(name: String, brand: String?, calories: Double, servingDescription: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(.primary)
                Text([brand, servingDescription].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(calories).formatted()) cal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Log Food Detail (serving / quantity / meal picker)

private struct LogFoodDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var localFoodItems: [FoodItem]

    let result: FoodResult?
    let existingFoodItem: FoodItem?
    let existingEntry: NutritionEntry?
    let onLogged: () -> Void

    private enum AmountMode: String, CaseIterable, Identifiable {
        case servings = "Servings"
        case weight = "Weight"
        var id: String { rawValue }
    }

    @State private var amountMode: AmountMode = .servings
    @State private var servingsCount: Double = 1
    @State private var weightValue: Double = 100
    @State private var weightUnit: WeightUnit = .grams
    @State private var mealType: MealType?
    @State private var showEditFood = false

    init(result: FoodResult, defaultMealType: MealType? = nil, existingEntry: NutritionEntry? = nil, onLogged: @escaping () -> Void) {
        self.result = result
        self.existingFoodItem = nil
        self.existingEntry = existingEntry
        self.onLogged = onLogged
        _mealType = State(initialValue: existingEntry?.mealType ?? defaultMealType)
        _servingsCount = State(initialValue: existingEntry?.quantity ?? 1)
        _weightValue = State(initialValue: result.servingSizeGrams > 0 ? result.servingSizeGrams : 100)
    }

    init(foodItem: FoodItem, defaultMealType: MealType? = nil, existingEntry: NutritionEntry? = nil, onLogged: @escaping () -> Void) {
        self.result = nil
        self.existingFoodItem = foodItem
        self.existingEntry = existingEntry
        self.onLogged = onLogged
        _mealType = State(initialValue: existingEntry?.mealType ?? defaultMealType)
        let grams = foodItem.servingSizeGrams > 0 ? foodItem.servingSizeGrams : 100
        if let existingEntry, existingEntry.foodItem === foodItem {
            _servingsCount = State(initialValue: existingEntry.quantity)
            _weightValue = State(initialValue: existingEntry.quantity * grams)
        } else {
            _servingsCount = State(initialValue: 1)
            _weightValue = State(initialValue: grams)
        }
    }

    private var name: String { existingFoodItem?.name ?? result?.name ?? "" }
    private var servingDescription: String { existingFoodItem?.servingDescription ?? result?.servingDescription ?? "" }
    private var caloriesPerServing: Double { existingFoodItem?.calories ?? result?.calories ?? 0 }
    private var servingSizeGrams: Double {
        let grams = existingFoodItem?.servingSizeGrams ?? result?.servingSizeGrams ?? 100
        return grams > 0 ? grams : 100
    }

    /// Quantity is expressed as a multiple of the food's base serving. In servings mode
    /// that's entered directly; in weight mode, converting the entered weight to grams and
    /// dividing by the serving size gives the same multiplier.
    private var quantity: Double {
        switch amountMode {
        case .servings: return servingsCount
        case .weight: return (weightValue * weightUnit.gramsPerUnit) / servingSizeGrams
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(name)
                        .font(.headline)
                    Text(servingDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let existingFoodItem {
                        Button {
                            showEditFood = true
                        } label: {
                            Label("Edit Nutrition Facts", systemImage: "pencil")
                        }
                        .sheet(isPresented: $showEditFood) {
                            EditFoodItemView(foodItem: existingFoodItem)
                        }
                    }
                }

                Section("Amount") {
                    Picker("Amount Type", selection: $amountMode) {
                        ForEach(AmountMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: amountMode) { oldMode, newMode in
                        guard oldMode != newMode else { return }
                        if newMode == .weight {
                            weightValue = (servingsCount * servingSizeGrams) / weightUnit.gramsPerUnit
                        } else {
                            servingsCount = (weightValue * weightUnit.gramsPerUnit) / servingSizeGrams
                        }
                    }

                    if amountMode == .servings {
                        HStack {
                            AutoSelectNumberField(value: $servingsCount, placeholder: "Servings")
                            Stepper("", value: $servingsCount, in: 0.25...50, step: 0.5)
                                .labelsHidden()
                            Text(servingsCount == 1 ? "serving" : "servings")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            AutoSelectNumberField(value: $weightValue, placeholder: "Amount")
                            Picker("Unit", selection: $weightUnit) {
                                ForEach(WeightUnit.allCases) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                            .onChange(of: weightUnit) { oldUnit, newUnit in
                                let grams = weightValue * oldUnit.gramsPerUnit
                                weightValue = grams / newUnit.gramsPerUnit
                            }
                        }
                    }
                }

                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(MealType?.some(meal))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Meal")
                } footer: {
                    if mealType == nil {
                        Text("Choose a meal to log this food.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    HStack {
                        Text("Calories")
                        Spacer()
                        Text("\(Int(caloriesPerServing * quantity).formatted())")
                            .foregroundStyle(Color.food)
                    }
                }

                if existingEntry != nil {
                    Section {
                        Button("Delete Entry", role: .destructive) { deleteEntry() }
                    }
                }
            }
            .navigationTitle(existingEntry != nil ? "Edit Entry" : "Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existingEntry != nil ? "Save" : "Add") { logEntry() }
                        .disabled(mealType == nil)
                }
            }
        }
    }

    private func logEntry() {
        guard let mealType else { return }
        let foodItem: FoodItem
        if let existingFoodItem {
            foodItem = existingFoodItem
        } else if let result, let match = localFoodItems.first(where: { $0.source == result.source && $0.externalId == result.externalId && result.externalId != nil }) {
            foodItem = match
        } else if let result {
            foodItem = FoodItem(
                name: result.name, brand: result.brand, barcode: result.barcode, source: result.source, externalId: result.externalId,
                servingSizeGrams: result.servingSizeGrams, servingDescription: result.servingDescription,
                calories: result.calories, proteinGrams: result.proteinGrams, carbsGrams: result.carbsGrams, fatGrams: result.fatGrams,
                sugarGrams: result.sugarGrams, fiberGrams: result.fiberGrams, sodiumMilligrams: result.sodiumMilligrams
            )
            modelContext.insert(foodItem)
        } else {
            return
        }

        if let existingEntry {
            existingEntry.foodItem = foodItem
            existingEntry.quantity = quantity
            existingEntry.mealType = mealType
        } else {
            let entry = NutritionEntry(mealType: mealType, quantity: quantity, foodItem: foodItem)
            modelContext.insert(entry)
        }
        try? modelContext.save()
        onLogged()
    }

    private func deleteEntry() {
        guard let existingEntry else { return }
        modelContext.delete(existingEntry)
        try? modelContext.save()
        onLogged()
    }
}

// MARK: - Custom Food Form

private struct CustomFoodFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let barcode: String?
    let existingEntry: NutritionEntry?
    let onLogged: () -> Void

    @State private var name = ""
    @State private var servingDescription = "1 serving"
    @State private var caloriesText = ""
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var sugarText = ""
    @State private var fiberText = ""
    @State private var sodiumText = ""
    @State private var mealType: MealType?
    @State private var showMoreNutrients = false

    init(barcode: String?, defaultMealType: MealType? = nil, existingEntry: NutritionEntry? = nil, onLogged: @escaping () -> Void) {
        self.barcode = barcode
        self.existingEntry = existingEntry
        self.onLogged = onLogged
        _mealType = State(initialValue: existingEntry?.mealType ?? defaultMealType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Serving (e.g. 1 bar, 1 cup)", text: $servingDescription)
                }

                Section("Nutrition per Serving") {
                    numberField("Calories", text: $caloriesText)
                    numberField("Protein (g)", text: $proteinText)
                    numberField("Carbs (g)", text: $carbsText)
                    numberField("Fat (g)", text: $fatText)
                }

                DisclosureGroup("More", isExpanded: $showMoreNutrients) {
                    numberField("Sugar (g)", text: $sugarText)
                    numberField("Fiber (g)", text: $fiberText)
                    numberField("Sodium (mg)", text: $sodiumText)
                }

                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(MealType?.some(meal))
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Meal")
                } footer: {
                    if mealType == nil {
                        Text("Choose a meal to log this food.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || mealType == nil)
                }
            }
        }
    }

    private func numberField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func save() {
        guard let mealType else { return }
        let foodItem = FoodItem(
            name: name, source: .custom, servingSizeGrams: 100, servingDescription: servingDescription,
            calories: Double(caloriesText) ?? 0, proteinGrams: Double(proteinText) ?? 0, carbsGrams: Double(carbsText) ?? 0,
            fatGrams: Double(fatText) ?? 0, sugarGrams: Double(sugarText) ?? 0, fiberGrams: Double(fiberText) ?? 0,
            sodiumMilligrams: Double(sodiumText) ?? 0, isUserCreated: true
        )
        if let barcode {
            foodItem.barcode = barcode
        }
        modelContext.insert(foodItem)

        if let existingEntry {
            existingEntry.foodItem = foodItem
            existingEntry.quantity = 1
            existingEntry.mealType = mealType
        } else {
            let entry = NutritionEntry(mealType: mealType, quantity: 1, foodItem: foodItem)
            modelContext.insert(entry)
        }
        try? modelContext.save()
        onLogged()
    }
}
