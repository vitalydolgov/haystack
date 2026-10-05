import Foundation
import TransactionalMacro

struct ReopenAccount {
    let unitOfWork: UnitOfWork

    // TODO: refactor with apply method
    @Transactional
    func execute(id: UUID) async throws {
        // TODO: guard with canExecute
        // TODO: check invariants before saving
        guard var account = try await store.accounts.query(id: id) else {
            throw AccountError.notFound
        }
        account.reopen()
        try await store.accounts.save(account)
    }
}
