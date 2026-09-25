import Foundation

/// Builds a CSV export of everything the user has tracked, one file per pillar
/// (Finances, Workouts, Nutrition) so the share sheet presents them as separate
/// "tabs" without needing a spreadsheet library. Each file is written to a temporary
/// directory and the caller is responsible for presenting/cleaning them up.
enum DataExportService {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func exportAll(
        transactions: [Transaction],
        bills: [Bill],
        income: Income?,
        savingsAccounts: [SavingsAccount],
        workoutSessions: [WorkoutSession],
        nutritionEntries: [NutritionEntry],
        waterEntries: [WaterEntry]
    ) -> [URL] {
        let files: [(name: String, contents: String)] = [
            ("Finances.csv", financesCSV(transactions: transactions, bills: bills, income: income, savingsAccounts: savingsAccounts)),
            ("Workouts.csv", workoutsCSV(sessions: workoutSessions)),
            ("Nutrition.csv", nutritionCSV(entries: nutritionEntries, waterEntries: waterEntries))
        ]

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AlfieTrackExport-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        return files.compactMap { file in
            let url = directory.appendingPathComponent(file.name)
            do {
                try file.contents.write(to: url, atomically: true, encoding: .utf8)
                return url
            } catch {
                return nil
            }
        }
    }

    // MARK: - Finances

    private static func financesCSV(transactions: [Transaction], bills: [Bill], income: Income?, savingsAccounts: [SavingsAccount]) -> String {
        var csv = ""

        csv += "Transactions\n"
        csv += csvRow(["Date", "Amount", "Category", "Note"])
        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            csv += csvRow([
                dateFormatter.string(from: transaction.date),
                amountString(transaction.amount),
                transaction.category?.name ?? "",
                transaction.note ?? ""
            ])
        }

        csv += "\n"
        csv += "Bills\n"
        csv += csvRow(["Name", "Amount", "Allocation", "Due Day", "Category", "Active", "Notes"])
        for bill in bills.sorted(by: { $0.name < $1.name }) {
            csv += csvRow([
                bill.name,
                amountString(bill.amount),
                amountString(bill.allocationAmount),
                String(bill.dueDay),
                bill.category?.name ?? "",
                bill.isActive ? "Yes" : "No",
                bill.notes ?? ""
            ])
        }

        csv += "\n"
        csv += "Income\n"
        csv += csvRow(["Amount", "Cadence", "Next Pay Date"])
        if let income {
            csv += csvRow([
                amountString(income.amount),
                income.cadence.displayName,
                dateFormatter.string(from: income.nextPayDate)
            ])
        }

        csv += "\n"
        csv += "Savings & Investments\n"
        csv += csvRow(["Name", "Balance", "Allocation Per Paycheck", "Last Reconciled"])
        for account in savingsAccounts.sorted(by: { $0.name < $1.name }) {
            csv += csvRow([
                account.name,
                amountString(account.balance),
                amountString(account.allocationPerPaycheck),
                account.lastReconciledPeriodEnd.map(dateFormatter.string) ?? ""
            ])
        }

        return csv
    }

    // MARK: - Workouts

    private static func workoutsCSV(sessions: [WorkoutSession]) -> String {
        var csv = ""

        csv += "Workout Sessions\n"
        csv += csvRow(["Date", "Name", "Template", "Duration (min)", "Exercises", "Total Volume", "PRs"])
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            csv += csvRow([
                dateFormatter.string(from: session.date),
                session.name,
                session.templateName ?? "",
                String(session.durationMinutes),
                String(session.exerciseCount),
                amountString(session.totalVolume),
                String(session.prCount)
            ])
        }

        csv += "\n"
        csv += "Logged Sets\n"
        csv += csvRow(["Date", "Session", "Exercise", "Set #", "Weight", "Reps", "Duration (sec)", "Warmup", "PR"])
        for session in sessions.sorted(by: { $0.date < $1.date }) {
            for set in (session.sets ?? []).sorted(by: { $0.setNumber < $1.setNumber }) {
                csv += csvRow([
                    dateFormatter.string(from: session.date),
                    session.name,
                    set.exercise?.name ?? "",
                    String(set.setNumber),
                    amountString(set.weight),
                    String(set.reps),
                    String(set.durationSeconds),
                    set.isWarmup ? "Yes" : "No",
                    set.isPR ? "Yes" : "No"
                ])
            }
        }

        return csv
    }

    // MARK: - Nutrition

    private static func nutritionCSV(entries: [NutritionEntry], waterEntries: [WaterEntry]) -> String {
        var csv = ""

        csv += "Nutrition Entries\n"
        csv += csvRow(["Date", "Meal", "Food", "Brand", "Quantity", "Calories", "Protein (g)", "Carbs (g)", "Fat (g)"])
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            csv += csvRow([
                dateFormatter.string(from: entry.date),
                entry.mealType.displayName,
                entry.foodItem?.name ?? "",
                entry.foodItem?.brand ?? "",
                amountString(entry.quantity),
                amountString(entry.calories),
                amountString(entry.proteinGrams),
                amountString(entry.carbsGrams),
                amountString(entry.fatGrams)
            ])
        }

        csv += "\n"
        csv += "Water Entries\n"
        csv += csvRow(["Date", "Ounces"])
        for entry in waterEntries.sorted(by: { $0.date < $1.date }) {
            csv += csvRow([
                dateFormatter.string(from: entry.date),
                amountString(entry.ounces)
            ])
        }

        return csv
    }

    // MARK: - Helpers

    private static func amountString(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func csvRow(_ fields: [String]) -> String {
        fields.map(csvEscape).joined(separator: ",") + "\n"
    }

    nonisolated private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
