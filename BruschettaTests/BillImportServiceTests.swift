import Testing
import Foundation
import SwiftData
@testable import Bruschetta

@MainActor
struct BillImportServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(AppSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return ModelContext(try ModelContainer(for: schema, configurations: [config]))
    }

    @Test
    func parsesStandaloneCSVWithQuotesAndOptionalColumns() throws {
        let csv = "Name,Amount,Due Day,Notes\nRent,\"1,500.00\",1,\"Includes \"\"parking\"\"\"\nPhone,45,15,\n"
        let (bills, invalid) = try BillImportService.parse(csv)
        #expect(invalid == 0)
        #expect(bills.count == 2)
        #expect(bills[0].amount == 1500)
        #expect(bills[0].allocationAmount == 1500)
        #expect(bills[0].notes == "Includes \"parking\"")
        #expect(bills[1].dueDay == 15)
    }

    @Test
    func findsBillsSectionInFinancesExport() throws {
        let csv = """
        Transactions
        Date,Amount,Category,Note
        2026-01-01 10:00,12.00,Gas,

        Bills
        Name,Amount,Allocation,Due Day,Category,Active,Notes
        Internet,70.00,35.00,20,Internet,No,

        Income
        Amount,Cadence,Next Pay Date
        """
        let (bills, _) = try BillImportService.parse(csv)
        #expect(bills.count == 1)
        #expect(bills[0].allocationAmount == 35)
        #expect(bills[0].isActive == false)
        #expect(bills[0].categoryName == "Internet")
    }

    @Test
    func skipsDuplicatesAndInvalidRowsAndCreatesCategories() throws {
        let context = try makeContext()
        context.insert(Bill(name: "Rent", amount: 1000, dueDay: 1))
        let (bills, invalid) = try BillImportService.parse("Name,Amount,Category\nrent,1,\nGym,30,Gym\n,5,\nBad,abc,\n")
        let result = BillImportService.apply(bills, invalidRows: invalid, to: context)
        #expect(result.imported == 1)
        #expect(result.skippedDuplicates == 1)
        #expect(result.invalidRows == 2)
        #expect(result.createdCategories == 1)
    }

    @Test
    func throwsWithoutRequiredHeaders() {
        #expect(throws: BillImportService.ImportError.self) {
            try BillImportService.parse("foo,bar\n1,2\n")
        }
    }
}

@MainActor
struct BillImportTemplateTests {
    @Test
    func templateParsesAndRoundTrips() throws {
        let (bills, invalid) = try BillImportService.parse(BillImportService.templateCSV)
        #expect(invalid == 0)
        #expect(bills.count == 4)
        #expect(bills.last?.isActive == false)
    }
}
