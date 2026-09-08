import Foundation
import TransactionalMacro

struct MoveTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID) -> Bool {
        fromAccountID != toAccountID
    }

    @Transactional
    func execute(id: UUID, toAccountID: UUID) async throws {
        guard let transaction = await store.transactions.find(id: id) else {
            throw TransactionError.notFound
        }
        guard let targetAccount = await store.accounts.find(id: toAccountID) else {
            throw AccountError.notFound
        }
        guard !targetAccount.isClosed else {
            throw AccountError.closed
        }
        guard transaction.accountID != toAccountID else { return }

        let moved = try Transaction(
            id: transaction.id,
            accountID: toAccountID,
            date: transaction.date,
            amount: transaction.amount,
            notes: transaction.notes,
            type: transaction.type
        )
        try await store.transactions.save(moved)
    }
}
// TODO: guard against .transfer transactions
