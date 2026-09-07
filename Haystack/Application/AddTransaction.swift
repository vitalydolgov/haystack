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
        guard let account = await store.accounts.find(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        let transaction = try Transaction(
            accountID: accountID,
            date: date,
            amount: amount,
            notes: notes
        )
        try await store.transactions.save(transaction)
        return transaction
    }
}
