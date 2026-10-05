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
        // TODO: guard with canExecute
        // TODO: check invariants before saving
        guard amount != 0 else { throw TransactionError.invalidAmount }
        guard let currentTx = try await store.transactions.query(id: id),
              case .standard = currentTx.type,
              currentTx.accountID == accountID else {
            throw TransactionError.notFound
        }
        guard var account = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        var updatedTx = currentTx
        try updatedTx.update(
            date: Self.dateComponents(from: date),
            amount: amount,
            notes: notes
        )
        account -= currentTx
        account += updatedTx
        try await store.accounts.save(account)
        try await store.transactions.save(updatedTx)
    }

    private static func dateComponents(from date: Date) -> (year: Int, month: Int, day: Int) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return (year: c.year!, month: c.month!, day: c.day!)
    }
}
