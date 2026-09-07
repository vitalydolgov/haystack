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

    func find(id: UUID) async -> Account? {
        await unitOfWork.store.accounts.find(id: id)
    }

    func delete(_ account: DeletedAccount) async throws {
        try await unitOfWork.perform { try await $0.accounts.delete(account) }
    }
}
