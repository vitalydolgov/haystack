import Foundation
import TransactionalMacro

struct AddTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    @Transactional
    func execute(
        accountID: UUID,
        date: Date = .now,
        amount: Decimal,
        notes: String = ""
    ) async throws -> Transaction {
        guard amount != 0 else { throw TransactionError.invalidAmount }
        guard let account = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        let transaction = try Transaction(
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        try await store.transactions.save(transaction)
        return transaction
    }
}
