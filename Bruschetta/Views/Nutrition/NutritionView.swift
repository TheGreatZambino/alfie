import SwiftUI
import SwiftData
import VisionKit

struct NutritionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NutritionEntry.date, order: .reverse) private var allEntries: [NutritionEntry]
    @Query(sort: \WaterEntry.date, order: .reverse) private var allWaterEntries: [WaterEntry]
    @Query private var goals: [NutritionGoals]

    @State private var showScanner = false
    @State private var showAddFood = false
    @State private var addFoodDefaultMeal: MealType?
    @State private var scannedResult: FoodResult?
    @State private var unmatchedBarcode: String?
    @State private var editingEntry: NutritionEntry?
    @State private var editingWaterEntry: WaterEntry?
    @State private var showSettings = false
    @State private var showDatePicker = false
    @State private var selectedDate = Date()

    @ObservedObject private var lookupService = FoodLookupService.shared

    private var todaysEntries: [NutritionEntry] {
        allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var todaysWaterEntries: [WaterEntry] {
        allWaterEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    /// Stamps a newly-logged entry with the currently browsed day but the real time-of-day,
    /// so quick-add entries on a past day still sort sensibly within that day.
    private func timestampOnSelectedDate() -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: Date())
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: selectedDate) ?? selectedDate
    }

    private var goal: NutritionGoals? { goals.first }

    private var totalCalories: Double { todaysEntries.reduce(0) { $0 + $1.calories } }
    private var calorieGoal: Double { goal?.calorieGoal ?? 2000 }
    private var caloriesRemaining: Double { calorieGoal - totalCalories }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header

                    dateNavHeader

                    TodayCard(entries: todaysEntries, goal: goal)

                    if goal?.isWaterTrackingEnabled ?? true {
                        WaterCard(entries: todaysWaterEntries, goalOunces: goal?.waterGoalOunces ?? 64) { ounces in
                            addWater(ounces: ounces)
                        } onEdit: { entry in
                            editingWaterEntry = entry
                        } onDelete: { entry in
                            modelContext.delete(entry)
                            try? modelContext.save()
                        }
                    }

                    LogActionsRow { openScanner() } onSearch: {
                        addFoodDefaultMeal = nil
                        showAddFood = true
                    } onRecent: {
                        addFoodDefaultMeal = nil
                        showAddFood = true
                    }

                    ForEach(MealType.allCases) { meal in
                        let entries = todaysEntries.filter { $0.mealType == meal }
                        MealSection(meal: meal, entries: entries, caloriesRemaining: caloriesRemaining) {
                            addFoodDefaultMeal = meal
                            showAddFood = true
                        } onDelete: { entry in
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } onEdit: { entry in
                            editingEntry = entry
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            .background(Color.paper)
            .safeAreaInset(edge: .bottom) { AdSlot() }
            .toolbar(.hidden, for: .navigationBar)
            .tint(.food)
            .fullScreenCover(isPresented: $showScanner) {
                BarcodeScannerScreen { barcode in
                    Task { await handleScannedBarcode(barcode) }
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodEntryView(unmatchedBarcode: unmatchedBarcode, defaultMealType: addFoodDefaultMeal, logDate: selectedDate)
                    .onDisappear { unmatchedBarcode = nil }
            }
            .sheet(item: $scannedResult) { result in
                AddFoodEntryView(prefillResult: result, logDate: selectedDate)
            }
            .sheet(item: $editingEntry) { entry in
                AddFoodEntryView(existingEntry: entry)
            }
            .sheet(item: $editingWaterEntry) { entry in
                EditWaterEntryView(entry: entry)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showDatePicker) {
                NutritionDatePickerSheet(selectedDate: $selectedDate)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NUTRITION")
                    .eyebrowStyle(color: .food)
                Text(headlineText)
                    .font(.screenHeadline)
                    .foregroundStyle(caloriesRemaining < 0 ? Color.training : Color.ink)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    openScanner()
                } label: {
                    Circle()
                        .fill(Color.card)
                        .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                        .overlay(
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.inkSecondary)
                        )
                        .frame(width: 36, height: 36)
                }
                Button {
                    showSettings = true
                } label: {
                    Circle()
                        .fill(Color.card)
                        .overlay(Circle().strokeBorder(Color.cardBorder, lineWidth: 1))
                        .overlay(
                            Image(systemName: "gearshape")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.inkSecondary)
                        )
                        .frame(width: 36, height: 36)
                }
            }
        }
        .frame(minHeight: 84)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var dateNavHeader: some View {
        HStack {
            Button {
                changeDay(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 32, height: 32)
            }

            Spacer()

            Button {
                showDatePicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(selectedDateLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
            }

            Spacer()

            Button {
                changeDay(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Calendar.current.isDateInToday(selectedDate) ? Color.inkTertiary.opacity(0.4) : Color.inkSecondary)
                    .frame(width: 32, height: 32)
            }
            .disabled(Calendar.current.isDateInToday(selectedDate))
        }
        .buttonStyle(.plain)
    }

    private var selectedDateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func changeDay(by days: Int) {
        guard let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        selectedDate = newDate
    }

    private var headlineText: String {
        if caloriesRemaining < 0 {
            return "Over by \(Int(-caloriesRemaining).formatted())"
        }
        return "\(Int(caloriesRemaining).formatted()) calories left"
    }

    private func openScanner() {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            showScanner = true
        } else {
            addFoodDefaultMeal = nil
            showAddFood = true
        }
    }

    private func addWater(ounces: Double) {
        modelContext.insert(WaterEntry(date: timestampOnSelectedDate(), ounces: ounces))
        try? modelContext.save()
    }

    private func handleScannedBarcode(_ barcode: String) async {
        if let result = await lookupService.lookupBarcode(barcode) {
            scannedResult = result
        } else {
            unmatchedBarcode = barcode
            addFoodDefaultMeal = nil
            showAddFood = true
        }
    }
}

// MARK: - Card 1: Today

private struct TodayCard: View {
    let entries: [NutritionEntry]
    let goal: NutritionGoals?

    private var totalCalories: Double { entries.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { entries.reduce(0) { $0 + $1.proteinGrams } }
    private var totalCarbs: Double { entries.reduce(0) { $0 + $1.carbsGrams } }
    private var totalFat: Double { entries.reduce(0) { $0 + $1.fatGrams } }
    private var calorieGoal: Double { goal?.calorieGoal ?? 2000 }

    var body: some View {
        HStack(spacing: 18) {
            RingGauge(progress: calorieGoal > 0 ? min(totalCalories / calorieGoal, 1) : 0, color: .food, lineWidth: 11, size: 118) {
                VStack(spacing: 0) {
                    Text("\(Int(totalCalories).formatted())")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                    Text("of \(Int(calorieGoal).formatted())")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                }
            }

            VStack(spacing: 12) {
                macroRow(label: "Protein", value: totalProtein, goal: goal?.proteinGoalGrams ?? 150)
                macroRow(label: "Carbs", value: totalCarbs, goal: goal?.carbsGoalGrams ?? 200)
                macroRow(label: "Fat", value: totalFat, goal: goal?.fatGoalGrams ?? 65)
            }
            .frame(maxWidth: .infinity)
        }
        .cardStyle()
    }

    private func macroRow(label: String, value: Double, goal: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSecondary)
                Spacer()
                Text("\(Int(value))g")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ink)
                Text("/\(Int(goal))g")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkTertiary)
            }
            SegmentedBar(segments: [.init(fraction: goal > 0 ? min(value / goal, 1) : 0, color: .food)], height: 7)
        }
    }
}

// MARK: - Water Card

private struct WaterCard: View {
    let entries: [WaterEntry]
    let goalOunces: Double
    let onAdd: (Double) -> Void
    let onEdit: (WaterEntry) -> Void
    let onDelete: (WaterEntry) -> Void

    @State private var showCustomEntry = false
    @State private var customAmountText = ""

    private var totalOunces: Double { entries.reduce(0) { $0 + $1.ounces } }
    private var progress: Double { goalOunces > 0 ? min(totalOunces / goalOunces, 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.food)
                    Text("WATER")
                        .sectionLabelStyle()
                }
                Spacer()
                Text("\(Int(totalOunces)) / \(Int(goalOunces)) oz")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
            }

            SegmentedBar(segments: [.init(fraction: progress, color: .food)], height: 7)

            HStack(spacing: 8) {
                quickAddButton(ounces: 8)
                quickAddButton(ounces: 16)
                quickAddButton(ounces: 24)
                Button {
                    customAmountText = ""
                    showCustomEntry = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.food)
                        .frame(width: 40, height: 32)
                        .background(Color.foodTint)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !entries.isEmpty {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        Button {
                            onEdit(entry)
                        } label: {
                            HStack {
                                Text("\(Int(entry.ounces)) oz")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkSecondary)
                                Spacer()
                                Text(entry.date, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                onEdit(entry)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                onDelete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } preview: {
                            HStack {
                                Text("\(Int(entry.ounces)) oz")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkSecondary)
                                Spacer()
                                Text(entry.date, style: .time)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                            .padding(14)
                            .frame(width: 260)
                            .background(Color.card)
                        }
                    }
                }
            }
        }
        .cardStyle()
        .alert("Add Water", isPresented: $showCustomEntry) {
            TextField("Ounces", text: $customAmountText)
                .keyboardType(.decimalPad)
            Button("Add") {
                if let amount = Double(customAmountText), amount > 0 {
                    onAdd(amount)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func quickAddButton(ounces: Double) -> some View {
        Button {
            onAdd(ounces)
        } label: {
            Text("+\(Int(ounces)) oz")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.food)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(Color.foodTint)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row 2: Log actions

private struct LogActionsRow: View {
    let onScan: () -> Void
    let onSearch: () -> Void
    let onRecent: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            actionButton(icon: "barcode.viewfinder", label: "Scan", action: onScan)
            actionButton(icon: "magnifyingglass", label: "Search", action: onSearch)
            actionButton(icon: "clock.arrow.circlepath", label: "Recent", action: onRecent)
        }
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.food)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Meal Section

private struct MealSection: View {
    let meal: MealType
    let entries: [NutritionEntry]
    let caloriesRemaining: Double
    let onAdd: () -> Void
    let onDelete: (NutritionEntry) -> Void
    let onEdit: (NutritionEntry) -> Void

    private var mealTotal: Double { entries.reduce(0) { $0 + $1.calories } }

    var body: some View {
        if entries.isEmpty {
            Button(action: onAdd) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("Add \(meal.displayName.lowercased())")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)

                    Spacer()

                    Text("\(Int(caloriesRemaining).formatted()) cal to spend")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.ink.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                )
            }
            .buttonStyle(.plain)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meal.displayName.uppercased())
                        .sectionLabelStyle()
                    Spacer()
                    Text("\(Int(mealTotal)) cal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                }
                .padding(.bottom, 8)

                VStack(spacing: 11) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        FoodEntryRowView(entry: entry, onEdit: { onEdit(entry) }, onDelete: { onDelete(entry) })
                            .contextMenu {
                                Button {
                                    onEdit(entry)
                                } label: {
                                    Label("Edit Entry", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        if index != entries.count - 1 {
                            Divider().overlay(Color.hairline)
                        }
                    }
                }
            }
            .cardStyle()
        }
    }
}

// MARK: - Date Picker Sheet

private struct NutritionDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    @State private var pickedDate: Date

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        self._pickedDate = State(initialValue: selectedDate.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("", selection: $pickedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.food)
                    .labelsHidden()
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    pickedDate = Date()
                } label: {
                    Text("Go to Today")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.food)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.foodTint)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedDate = pickedDate
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(560), .large])
        .presentationDragIndicator(.visible)
    }
}
