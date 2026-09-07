import Foundation
import TransactionalMacro

struct EditTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    @Transactional
    func execute(
        id: UUID,
        accountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard let existing = await store.transactions.find(id: id),
              existing.accountID == accountID else {
            throw TransactionError.notFound
        }
        guard let account = await store.accounts.find(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else {
            throw AccountError.closed
        }
        var updated = existing
        try updated.update(
            date: Self.dateComponents(from: date),
            amount: amount,
            notes: notes
        )
        try await store.transactions.save(updated)
    }

    private static func dateComponents(from date: Date) -> (year: Int, month: Int, day: Int) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return (year: c.year!, month: c.month!, day: c.day!)
    }
}
