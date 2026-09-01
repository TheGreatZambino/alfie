import AppIntents
import SwiftData

struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Expense"
    static var description = IntentDescription("Add a new transaction to Alfie Track.")

    @Parameter(title: "Amount", description: "The amount spent")
    var amount: Double

    @Parameter(title: "Category", description: "The spending category")
    var category: CategoryEntity?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) expense in \(\.$category)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(AppModelContainer.shared)

        let resolvedCategory = category
            .flatMap { PersistentIdentifier.from(appEntityID: $0.id) }
            .flatMap { context.model(for: $0) as? Category }
        let transaction = Transaction(amount: amount, date: .now, note: note, category: resolvedCategory)
        context.insert(transaction)
        try context.save()

        let amountText = amount.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD"))
        let categoryName = resolvedCategory?.name ?? "Uncategorized"
        return .result(dialog: "Logged \(amountText) to \(categoryName).")
    }
}
