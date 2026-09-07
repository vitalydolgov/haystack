import Foundation

struct MoveTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID) -> Bool {
        fromAccountID != toAccountID
    }

    func execute(id: UUID, toAccountID: UUID) async throws {
        try await unitOfWork.perform { store in
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
                date: Transaction.date(from: transaction.date),
                amount: transaction.amount,
                notes: transaction.notes,
                type: transaction.type
            )
            try await store.transactions.save(moved)
        }
    }
}
