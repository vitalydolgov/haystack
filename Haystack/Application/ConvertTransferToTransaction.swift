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
        guard amount != 0 else { throw TransactionError.invalidAmount }

        // figure out what to keep
        guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: transferID) else {
            throw TransferError.notFound
        }
        let (keptLeg, droppedLeg): (Transaction, Transaction)
        switch accountID {
        case fromLeg.accountID:
            (keptLeg, droppedLeg) = (fromLeg, toLeg)
        case toLeg.accountID:
            (keptLeg, droppedLeg) = (toLeg, fromLeg)
        default:
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
        let destinationID = destinationAccountID ?? keptLeg.accountID
        let convertedTx = try Transaction(
            id: keptLeg.id,
            accountID: destinationID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        guard var account = try await store.accounts.query(id: destinationID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        account += convertedTx
        try await store.accounts.save(account)
        try await store.transactions.save(convertedTx)
    }
}
