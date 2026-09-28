import Foundation
import SwiftData
@testable import Haystack

struct DurableAccountRepository: AccountRepository {
    let unitOfWork: SwiftDataUnitOfWork

    init(modelContainer: ModelContainer) {
        self.unitOfWork = SwiftDataUnitOfWork(modelContainer: modelContainer)
    }

    func save(_ account: Account) async throws {
        try await unitOfWork.perform { try await $0.accounts.save(account) }
    }

    func query(id: UUID, includeDeleted: Bool) async throws -> Account? {
        try await unitOfWork.store.accounts.query(id: id, includeDeleted: includeDeleted)
    }

    func query(_ query: AccountQuery) async throws -> [Account] {
        try await unitOfWork.store.accounts.query(query)
    }

    func delete(_ account: DeletedAccount) async throws {
        try await unitOfWork.perform { try await $0.accounts.delete(account) }
    }
}
