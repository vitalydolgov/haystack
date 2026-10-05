import Foundation
import SwiftData

actor SwiftDataAccountRepository: AccountRepository, ModelActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(modelContainer: ModelContainer, modelExecutor: any ModelExecutor) {
        self.modelContainer = modelContainer
        self.modelExecutor = modelExecutor
    }

    func save(_ account: Account) throws {
        if let record = record(id: account.id) {
            guard record.deletedAt == nil else { return }
            record.update(from: account)
        } else {
            modelContext.insert(AccountRecord(account))
        }
    }

    func save(batch: [Account]) throws {
        for account in batch {
            try save(account)
        }
    }

    func query(id: UUID, includeDeleted: Bool) throws -> Account? {
        let descriptor = descriptor(id: id, includeDeleted: includeDeleted)
        guard let record = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return try record.toAccount()
    }

    func query(_ query: AccountQuery) throws -> [Account] {
        try modelContext.fetch(descriptor(for: query)).map { try $0.toAccount() }
    }

    func delete(_ account: DeletedAccount) throws {
        guard let record = record(id: account.id), record.deletedAt == nil else { return }
        record.deletedAt = account.deletedAt
    }

    private func descriptor(for query: AccountQuery) -> FetchDescriptor<AccountRecord> {
        switch query {
        case .open:
            return FetchDescriptor(
                predicate: #Predicate { $0.deletedAt == nil && !$0.isClosed },
                sortBy: [SortDescriptor(\.name)]
            )
        case .includingClosed:
            return FetchDescriptor(
                predicate: #Predicate { $0.deletedAt == nil },
                sortBy: [SortDescriptor(\.name)]
            )
        }
    }

    private func descriptor(id: UUID, includeDeleted: Bool) -> FetchDescriptor<AccountRecord> {
        let accountID = id
        var descriptor: FetchDescriptor<AccountRecord>
        if includeDeleted {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.id == accountID })
        } else {
            descriptor = FetchDescriptor(predicate: #Predicate { $0.id == accountID && $0.deletedAt == nil })
        }
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func record(id: UUID) -> AccountRecord? {
        var descriptor = FetchDescriptor<AccountRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}
