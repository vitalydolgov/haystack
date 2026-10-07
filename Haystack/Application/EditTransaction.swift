import Foundation
import TransactionalMacro

struct EditTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        id: UUID,
        accountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard Self.canExecute(amount: amount) else {
            throw ApplicationError.cannotExecute
        }
        // TODO: check invariants before saving
        guard let currentTx = try await store.transactions.query(id: id),
              case .standard = currentTx.type else {
            throw TransactionError.notFound
        }
        guard var account = try await store.accounts.query(id: currentTx.accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }

        let updatedTx = try Transaction(
            id: currentTx.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: currentTx.type
        )

        if currentTx.accountID == accountID {
            account -= currentTx
            account += updatedTx
            try await store.accounts.save(account)
        } else {
            guard var movingToAccount = try await store.accounts.query(id: accountID) else {
                throw AccountError.notFound
            }
            guard !movingToAccount.isClosed else { throw AccountError.closed }
            account -= currentTx
            movingToAccount += updatedTx
            try await store.accounts.save(account)
            try await store.accounts.save(movingToAccount)
        }
        try await store.transactions.save(updatedTx)
    }
}
