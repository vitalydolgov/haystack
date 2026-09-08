import Foundation
import TransactionalMacro

struct ConvertTransferToTransaction {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    @Transactional
    func execute(
        transferID: UUID,
        keeping accountID: UUID,
        movingTo destinationAccountID: UUID? = nil,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard let (fromLeg, toLeg) = await store.transactions.findTransfer(id: transferID) else {
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
        let destinationID = destinationAccountID ?? keptLeg.accountID
        guard let account = await store.accounts.find(id: destinationID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else {
            throw AccountError.closed
        }
        let converted = try Transaction(
            id: keptLeg.id,
            accountID: destinationID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        try await store.transactions.save(converted)
        try await store.transactions.delete(droppedLeg.delete())
    }
}
