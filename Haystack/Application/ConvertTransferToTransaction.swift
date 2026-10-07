import Foundation
import TransactionalMacro

struct ConvertTransferToTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        transferID: UUID,
        keeping accountID: UUID,
        movingTo destinationAccountID: UUID? = nil,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard Self.canExecute(amount: amount) else {
            throw ApplicationError.cannotExecute
        }
        // TODO: check invariants before saving
        guard let (keptLeg, droppedLeg) = try await store.transactions.queryTransfer(
            id: transferID,
            relativeTo: accountID
        ) else {
            if try await store.transactions.queryTransfer(id: transferID) == nil {
                throw TransferError.notFound
            }
            throw TransactionError.notFound
        }

        // remove kept leg
        guard var keptAccount = try await store.accounts.query(id: keptLeg.accountID) else {
            throw AccountError.notFound
        }
        keptAccount -= keptLeg
        try await store.accounts.save(keptAccount)

        // remove dropped leg
        guard var droppedAccount = try await store.accounts.query(id: droppedLeg.accountID) else {
            throw AccountError.notFound
        }
        droppedAccount -= droppedLeg
        try await store.accounts.save(droppedAccount)
        try await store.transactions.delete(droppedLeg.delete())

        // add transaction
        let accountID = destinationAccountID ?? keptLeg.accountID
        let transaction = try Transaction(
            id: keptLeg.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        guard var account = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        account += transaction
        try await store.accounts.save(account)
        try await store.transactions.save(transaction)
    }
}
