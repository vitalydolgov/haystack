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
        guard var source = try await store.accounts.query(id: currentTx.accountID) else {
            throw AccountError.notFound
        }
        guard !source.isClosed else { throw AccountError.closed }

        let updatedTx = try Transaction(
            id: currentTx.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: currentTx.type
        )

        if currentTx.accountID == accountID {
            source -= currentTx
            source += updatedTx
            try await store.accounts.save(source)
        } else {
            guard var target = try await store.accounts.query(id: accountID) else {
                throw AccountError.notFound
            }
            guard !target.isClosed else { throw AccountError.closed }
            source -= currentTx
            target += updatedTx
            try await store.accounts.save(source)
            try await store.accounts.save(target)
        }
        try await store.transactions.save(updatedTx)
    }
}
