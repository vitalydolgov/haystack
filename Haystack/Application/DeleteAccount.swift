import Foundation
import TransactionalMacro

struct DeleteAccount {
    // TODO: purge accounts whose deletedAt is older than the retention window
    let unitOfWork: UnitOfWork

    // TODO: refactor with apply method
    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let account = try await store.accounts.query(id: id) else {
            throw AccountError.notFound
        }
        let deleted = try account.delete(at: date)
        try await store.accounts.delete(deleted)
    }
}
