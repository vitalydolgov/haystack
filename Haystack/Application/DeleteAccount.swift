import Foundation
import TransactionalMacro

struct DeleteAccount {
    // TODO: purge accounts whose deletedAt is older than the retention window
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let account = await store.accounts.find(id: id) else {
            throw AccountError.notFound
        }
        let deleted = try account.delete(at: date)
        try await store.accounts.delete(deleted)
    }
}
