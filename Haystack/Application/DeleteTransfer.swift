import Foundation
import TransactionalMacro

struct DeleteTransfer {
    let unitOfWork: UnitOfWork

    static func apply(
        account: inout Account,
        counterpartAccount: inout Account,
        transaction: Transaction,
        counterpartTransaction: Transaction,
        at date: Date = .now
    ) -> (DeletedTransaction, DeletedTransaction) {
        account -= transaction
        counterpartAccount -= counterpartTransaction
        return (transaction.delete(at: date), counterpartTransaction.delete(at: date))
    }

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        // TODO: check invariants before saving
        guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: id) else {
            throw TransferError.notFound
        }
        guard var fromAccount = try await store.accounts.query(id: fromLeg.accountID) else {
            throw AccountError.notFound
        }
        guard var toAccount = try await store.accounts.query(id: toLeg.accountID) else {
            throw AccountError.notFound
        }
        let (deleted, deletedCounterpart) = Self.apply(
            account: &fromAccount,
            counterpartAccount: &toAccount,
            transaction: fromLeg,
            counterpartTransaction: toLeg,
            at: date
        )
        try await store.accounts.save(fromAccount)
        try await store.transactions.delete(deleted)
        try await store.accounts.save(toAccount)
        try await store.transactions.delete(deletedCounterpart)
    }
}
