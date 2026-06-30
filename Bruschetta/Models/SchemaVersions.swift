import SwiftData

enum BudgetSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Income.self, Category.self, Bill.self, Transaction.self]
    }
}

enum BudgetMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BudgetSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
