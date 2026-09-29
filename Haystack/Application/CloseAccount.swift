import Foundation
import TransactionalMacro

struct CloseAccount {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID) async throws {
        guard var account = try await store.accounts.query(id: id) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { return }
        if account.balance != 0 {
            account = try await AdjustBalance(unitOfWork: unitOfWork).execute(id: id, to: 0)
        }
        try account.close()
        try await store.accounts.save(account)
    }
}
