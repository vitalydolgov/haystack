import Foundation
import TransactionalMacro

struct AdjustBalance {
    let unitOfWork: UnitOfWork

    // TODO: refactor with apply method
    @Transactional
    func execute(id: UUID, to balance: Decimal, on date: Date = .now) async throws -> Account {
        // TODO: guard with canExecute
        // TODO: check invariants before saving
        guard var account = try await store.accounts.query(id: id) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        let delta = balance - account.balance
        guard delta != 0 else { throw TransactionError.invalidAmount }
        let transaction = try Transaction(
            accountID: id,
            date: date.asYearMonthDay(),
            amount: delta,
            type: .standard
        )
        account += transaction
        try await store.accounts.save(account)
        try await store.transactions.save(transaction)
        return account
    }
}
