import Foundation
import TransactionalMacro

struct DeleteTransaction {
    let unitOfWork: UnitOfWork

    static func apply(
        account: inout Account,
        transaction: Transaction,
        at date: Date = .now
    ) -> DeletedTransaction {
        account -= transaction
        return transaction.delete(at: date)
    }

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let transaction = try await store.transactions.query(id: id),
              case .standard = transaction.type else {
            throw TransactionError.notFound
        }
        guard var account = try await store.accounts.query(id: transaction.accountID) else {
            throw AccountError.notFound
        }
        let deleted = Self.apply(account: &account, transaction: transaction, at: date)
        try await store.accounts.save(account)
        try await store.transactions.delete(deleted)
    }
}
