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
        try await AdjustBalance(unitOfWork: unitOfWork).execute(id: id, to: 0)
        let transactions = await store.transactions.find(accountID: id)
        try account.close(transactions)
        try await store.accounts.save(account)
    }
}
