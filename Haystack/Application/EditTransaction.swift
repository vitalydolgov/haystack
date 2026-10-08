import Foundation
import TransactionalMacro

struct EditTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    static func apply(
        _ transaction: Transaction,
        account: inout Account,
        date: Date,
        amount: Decimal,
        notes: String
    ) throws -> Transaction {
        guard account.id == transaction.accountID else { throw AccountError.notFound }
        guard !account.isClosed else { throw AccountError.closed }
        let updated = try Transaction(
            id: transaction.id,
            accountID: account.id,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: transaction.type
        )
        account -= transaction
        account += updated
        return updated
    }

    static func apply(
        _ transaction: Transaction,
        account: inout Account,
        movingTo destination: inout Account,
        date: Date,
        amount: Decimal,
        notes: String
    ) throws -> Transaction {
        guard account.id == transaction.accountID else { throw AccountError.notFound }
        guard !account.isClosed, !destination.isClosed else { throw AccountError.closed }
        let updated = try Transaction(
            id: transaction.id,
            accountID: destination.id,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: transaction.type
        )
        account -= transaction
        destination += updated
        return updated
    }

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

        let updatedTx: Transaction
        if currentTx.accountID == accountID {
            updatedTx = try Self.apply(
                currentTx,
                account: &account,
                date: date,
                amount: amount,
                notes: notes
            )
        } else {
            guard var destination = try await store.accounts.query(id: accountID) else {
                throw AccountError.notFound
            }
            updatedTx = try Self.apply(
                currentTx,
                account: &account,
                movingTo: &destination,
                date: date,
                amount: amount,
                notes: notes
            )
            try await store.accounts.save(destination)
        }
        try await store.accounts.save(account)
        try await store.transactions.save(updatedTx)
    }
}
