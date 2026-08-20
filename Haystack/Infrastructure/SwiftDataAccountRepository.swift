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
            record.update(from: account)
        } else {
            modelContext.insert(AccountRecord(account))
        }
        try modelContext.save()
    }

    func find(id: UUID) -> Account? {
        try? record(id: id)?.toAccount()
    }

    func delete(_ account: Account) throws {
        guard let record = record(id: account.id) else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    private func record(id: UUID) -> AccountRecord? {
        let accountID = id
        var descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.id == accountID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
