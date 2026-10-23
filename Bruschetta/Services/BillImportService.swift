import Foundation
import SwiftData

/// Imports bills from a CSV file. Accepts either a standalone bills CSV or the
/// "Finances.csv" produced by `DataExportService` (the "Bills" section is located
/// automatically), so an export from one install can be restored into another.
///
/// Columns are matched by header name (case-insensitive), so order doesn't matter:
/// `Name` and `Amount` are required; `Allocation`, `Due Day`, `Category`, `Active`
/// and `Notes` are optional.
enum BillImportService {
    struct ParsedBill: Equatable {
        var name: String
        var amount: Double
        var allocationAmount: Double
        var dueDay: Int
        var categoryName: String?
        var isActive: Bool
        var notes: String?
    }

    struct Result: Equatable {
        var imported = 0
        var skippedDuplicates = 0
        var invalidRows = 0
        var createdCategories = 0

        var summary: String {
            var parts = ["Imported \(imported) bill\(imported == 1 ? "" : "s")."]
            if skippedDuplicates > 0 { parts.append("Skipped \(skippedDuplicates) already in the app.") }
            if invalidRows > 0 { parts.append("Skipped \(invalidRows) row\(invalidRows == 1 ? "" : "s") that were missing a name or amount.") }
            if createdCategories > 0 { parts.append("Created \(createdCategories) new categor\(createdCategories == 1 ? "y" : "ies").") }
            return parts.joined(separator: " ")
        }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case noBillsFound

        var errorDescription: String? {
            switch self {
            case .unreadable: return "That file couldn't be read as text."
            case .noBillsFound: return "No bills found. The file needs a header row with at least \"Name\" and \"Amount\" columns."
            }
        }
    }

    // MARK: - Template

    static let templateCSV = """
    Name,Amount,Allocation,Due Day,Category,Active,Notes
    Rent,1500.00,750.00,1,Housing,Yes,Example - replace with your own bills
    Electric,120.00,60.00,15,Utilities,Yes,
    Internet,70.00,35.00,20,Internet,Yes,
    Phone,45.00,22.50,25,Phone,No,Inactive bills are imported but not counted

    """

    /// Writes the example template to a temporary file for sharing; returns nil on failure.
    static func writeTemplate() -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AlfieTrackTemplate-\(UUID().uuidString)", isDirectory: true)
        let url = directory.appendingPathComponent("Bills Template.csv")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try templateCSV.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Import

    @MainActor
    static func importBills(from url: URL, into context: ModelContext) throws -> Result {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { throw ImportError.unreadable }

        let (bills, invalid) = try parse(text)
        return apply(bills, invalidRows: invalid, to: context)
    }

    @MainActor
    static func apply(_ parsed: [ParsedBill], invalidRows: Int = 0, to context: ModelContext) -> Result {
        var result = Result(invalidRows: invalidRows)

        let existingBills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []
        var knownNames = Set(existingBills.map { $0.name.lowercased() })

        var categories = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var nextSortOrder = (categories.map(\.sortOrder).max() ?? -1) + 1

        for item in parsed {
            let key = item.name.lowercased()
            guard !knownNames.contains(key) else {
                result.skippedDuplicates += 1
                continue
            }
            knownNames.insert(key)

            var category: Category?
            if let categoryName = item.categoryName {
                category = categories.first { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }
                if category == nil {
                    let defaults = Category.defaultCategories.first { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }
                    let created = Category(
                        name: defaults?.name ?? categoryName,
                        icon: defaults?.icon ?? "circle.fill",
                        colorHex: defaults?.colorHex ?? "#9E9E9E",
                        sortOrder: nextSortOrder
                    )
                    nextSortOrder += 1
                    context.insert(created)
                    categories.append(created)
                    result.createdCategories += 1
                    category = created
                }
            }

            context.insert(Bill(
                name: item.name,
                amount: item.amount,
                allocationAmount: item.allocationAmount,
                dueDay: item.dueDay,
                category: category,
                isActive: item.isActive,
                notes: item.notes
            ))
            result.imported += 1
        }

        try? context.save()
        return result
    }

    // MARK: - Parsing

    static func parse(_ text: String) throws -> (bills: [ParsedBill], invalidRows: Int) {
        let rows = csvRows(text)

        // Find the header row: the first row containing both "name" and "amount".
        // This also skips the "Bills" section title in a full Finances export.
        guard let headerIndex = rows.firstIndex(where: { row in
            let lowered = row.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            return lowered.contains("name") && lowered.contains("amount")
        }) else { throw ImportError.noBillsFound }

        let headers = rows[headerIndex].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        func column(_ names: String...) -> Int? { names.compactMap { headers.firstIndex(of: $0) }.first }

        guard let nameCol = column("name"), let amountCol = column("amount") else { throw ImportError.noBillsFound }
        let allocationCol = column("allocation", "allocation amount", "allocate per paycheck")
        let dueCol = column("due day", "due date", "due")
        let categoryCol = column("category")
        let activeCol = column("active")
        let notesCol = column("notes", "note")

        var bills: [ParsedBill] = []
        var invalid = 0

        for row in rows[(headerIndex + 1)...] {
            // A blank line ends the Bills section of a multi-section export.
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                if bills.isEmpty && invalid == 0 { continue }
                break
            }

            func field(_ index: Int?) -> String {
                guard let index, index < row.count else { return "" }
                return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let name = field(nameCol)
            guard !name.isEmpty, let amount = parseAmount(field(amountCol)) else {
                invalid += 1
                continue
            }

            let allocation = parseAmount(field(allocationCol)) ?? amount
            let dueDay = min(max(Int(field(dueCol).filter(\.isNumber)) ?? 1, 1), 31)
            let category = field(categoryCol)
            let active = parseBool(field(activeCol)) ?? true
            let notes = field(notesCol)

            bills.append(ParsedBill(
                name: name,
                amount: amount,
                allocationAmount: allocation,
                dueDay: dueDay,
                categoryName: category.isEmpty ? nil : category,
                isActive: active,
                notes: notes.isEmpty ? nil : notes
            ))
        }

        if bills.isEmpty && invalid == 0 { throw ImportError.noBillsFound }
        return (bills, invalid)
    }

    private static func parseAmount(_ string: String) -> Double? {
        let cleaned = string.filter { $0.isNumber || $0 == "." || $0 == "-" }
        return cleaned.isEmpty ? nil : Double(cleaned)
    }

    private static func parseBool(_ string: String) -> Bool? {
        switch string.lowercased() {
        case "yes", "y", "true", "1", "active": return true
        case "no", "n", "false", "0", "inactive": return false
        default: return nil
        }
    }

    /// RFC 4180-style CSV parser: handles quoted fields, escaped quotes, and embedded newlines.
    static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n"))
        if chars.first == "\u{FEFF}" { chars.removeFirst() }

        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}
