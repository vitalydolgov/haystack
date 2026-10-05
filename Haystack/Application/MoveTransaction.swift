import Foundation
import TransactionalMacro

struct MoveTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID) -> Bool {
        fromAccountID != toAccountID
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(id: UUID, movingTo accountID: UUID) async throws {
        guard let originalTx = try await store.transactions.query(id: id),
              case .standard = originalTx.type else {
            throw TransactionError.notFound
        }
        guard originalTx.accountID != accountID else { return }
        guard var source = try await store.accounts.query(id: originalTx.accountID),
              var target = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        guard !source.isClosed, !target.isClosed else { throw AccountError.closed }
        let movedTx = try Transaction(
            id: originalTx.id,
            accountID: accountID,
            date: originalTx.date,
            amount: originalTx.amount,
            notes: originalTx.notes,
            type: originalTx.type
        )
        source -= originalTx
        target += movedTx
        try await store.accounts.save(source)
        try await store.accounts.save(target)
        try await store.transactions.save(movedTx)
    }
}
