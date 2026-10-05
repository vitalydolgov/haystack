import Foundation
import TransactionalMacro

struct DeleteTransfer {
    let unitOfWork: UnitOfWork

    static func apply(
        fromAccount: inout Account,
        toAccount: inout Account,
        fromLeg: Transaction,
        toLeg: Transaction,
        at date: Date = .now
    ) -> (DeletedTransaction, DeletedTransaction) {
        fromAccount -= fromLeg
        toAccount -= toLeg
        return (fromLeg.delete(at: date), toLeg.delete(at: date))
    }

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        // TODO: guard with canExecute
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
        let (deletedFrom, deletedTo) = Self.apply(
            fromAccount: &fromAccount,
            toAccount: &toAccount,
            fromLeg: fromLeg,
            toLeg: toLeg,
            at: date
        )
        try await store.accounts.save(fromAccount)
        try await store.transactions.delete(deletedFrom)
        try await store.accounts.save(toAccount)
        try await store.transactions.delete(deletedTo)
    }
}
