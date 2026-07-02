import SwiftData

enum BudgetSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Income.self, Category.self, Bill.self, Transaction.self]
    }
}

enum BudgetSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Income.self, Category.self, Bill.self, Transaction.self,
            Exercise.self, WorkoutTemplate.self, TemplateExerciseEntry.self, WorkoutSession.self, LoggedSet.self
        ]
    }
}

enum BudgetMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [BudgetSchemaV1.self, BudgetSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: BudgetSchemaV1.self,
        toVersion: BudgetSchemaV2.self
    )
}
