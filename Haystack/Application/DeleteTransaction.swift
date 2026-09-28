import Foundation
import TransactionalMacro

struct DeleteTransaction {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let transaction = try await store.transactions.query(id: id),
              transaction.type != .transfer else {
            throw TransactionError.notFound
        }
        guard var account = try await store.accounts.query(id: transaction.accountID) else {
            throw AccountError.notFound
        }
        account -= transaction
        try await store.accounts.save(account)
        try await store.transactions.delete(transaction.delete(at: date))
    }
}
