import Foundation
import TransactionalMacro

struct AddTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID, magnitude: Decimal) -> Bool {
        fromAccountID != toAccountID && magnitude > 0
    }

    static func apply(
        account: inout Account,
        counterpartAccount: inout Account,
        date: Date = .now,
        amount: Decimal,
        notes: String = ""
    ) throws -> (Transaction, Transaction) {
        guard account.id != counterpartAccount.id else { throw TransferError.sameAccount }
        guard !account.isClosed, !counterpartAccount.isClosed else { throw AccountError.closed }
        let transferID = UUID()
        let day = date.asYearMonthDay()
        let transaction = try Transaction(
            accountID: account.id,
            date: day,
            amount: amount,
            notes: notes,
            type: .transfer(transferID)
        )
        let counterpartTransaction = try Transaction(
            accountID: counterpartAccount.id,
            date: day,
            amount: -amount,
            notes: notes,
            type: .transfer(transferID)
        )
        account += transaction
        counterpartAccount += counterpartTransaction
        return (transaction, counterpartTransaction)
    }

    @Transactional
    func execute(
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date = .now,
        magnitude: Decimal,
        notes: String = ""
    ) async throws -> (Transaction, Transaction) {
        guard var fromAccount = try await store.accounts.query(id: fromAccountID),
              var toAccount = try await store.accounts.query(id: toAccountID) else {
            throw AccountError.notFound
        }
        let (fromLeg, toLeg) = try Self.apply(
            account: &fromAccount,
            counterpartAccount: &toAccount,
            date: date,
            amount: -magnitude,
            notes: notes
        )
        try await store.accounts.save(fromAccount)
        try await store.transactions.save(fromLeg)
        try await store.accounts.save(toAccount)
        try await store.transactions.save(toLeg)
        return (fromLeg, toLeg)
    }
}
