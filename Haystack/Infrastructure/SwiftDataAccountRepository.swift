import Foundation
import SwiftData

actor SwiftDataAccountRepository: AccountRepository, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
    }

    func save(_ account: Account) throws {
        if let record = record(id: account.id) {
            guard record.deletedAt == nil else { return }
            record.update(from: account)
        } else {
            modelContext.insert(AccountRecord(account))
        }
        try modelContext.save()
    }

    func find(id: UUID) -> Account? {
        guard let record = record(id: id), record.deletedAt == nil else { return nil }
        return try? record.toAccount()
    }

    func delete(_ account: DeletedAccount) throws {
        guard let record = record(id: account.id), record.deletedAt == nil else { return }
        record.deletedAt = account.deletedAt
        try modelContext.save()
    }

    private func record(id: UUID) -> AccountRecord? {
        var descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
