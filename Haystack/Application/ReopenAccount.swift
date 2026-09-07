import Foundation
import TransactionalMacro

struct ReopenAccount {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID) async throws {
        guard var account = await store.accounts.find(id: id) else {
            throw AccountError.notFound
        }
        account.reopen()
        try await store.accounts.save(account)
    }
}
