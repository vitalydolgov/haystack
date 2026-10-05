import Foundation
import TransactionalMacro

struct AddTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    static func apply(
        account: inout Account,
        date: Date = .now,
        amount: Decimal,
        notes: String = "",
        splitID: UUID? = nil
    ) throws -> Transaction {
        guard amount != 0 else { throw TransactionError.invalidAmount }
        guard !account.isClosed else { throw AccountError.closed }
        let type: TransactionType = if let splitID {
            .splitPart(splitID, .standard)
        } else {
            .standard
        }
        let transaction = try Transaction(
            accountID: account.id,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: type
        )
        account += transaction
        return transaction
    }

    @Transactional
    func execute(
        accountID: UUID,
        date: Date = .now,
        amount: Decimal,
        notes: String = "",
        splitID: UUID? = nil
    ) async throws -> Transaction {
        guard var account = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        let transaction = try Self.apply(
            account: &account,
            date: date,
            amount: amount,
            notes: notes,
            splitID: splitID
        )
        try await store.accounts.save(account)
        try await store.transactions.save(transaction)
        return transaction
    }
}
