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
        accountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard let (fromLeg, toLeg) = await store.transactions.findTransfer(id: transferID) else {
            throw TransferError.notFound
        }
        let keptLeg = fromLeg.accountID == accountID ? fromLeg : toLeg
        let droppedLeg = fromLeg.accountID == accountID ? toLeg : fromLeg
        guard keptLeg.accountID == accountID else {
            throw TransactionError.notFound
        }
        guard let account = await store.accounts.find(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else {
            throw AccountError.closed
        }
        let converted = try Transaction(
            id: keptLeg.id,
            accountID: keptLeg.accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        try await store.transactions.save(converted)
        try await store.transactions.delete(droppedLeg.delete())
    }
}
