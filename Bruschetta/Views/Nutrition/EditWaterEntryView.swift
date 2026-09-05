import SwiftUI
import SwiftData

struct EditWaterEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let entry: WaterEntry

    @State private var amountText: String
    @State private var date: Date

    init(entry: WaterEntry) {
        self.entry = entry
        _amountText = State(initialValue: String(format: "%.0f", entry.ounces))
        _date = State(initialValue: entry.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                        Text("ounces")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Time") {
                    DatePicker("Logged at", selection: $date)
                        .datePickerStyle(.compact)
                }

                Section {
                    Button("Delete Entry", role: .destructive) {
                        delete()
                    }
                }
            }
            .navigationTitle("Edit Water Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(Double(amountText) == nil || Double(amountText) == 0)
                }
            }
        }
    }

    private func save() {
        guard let amount = Double(amountText), amount > 0 else { return }
        entry.ounces = amount
        entry.date = date
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}
