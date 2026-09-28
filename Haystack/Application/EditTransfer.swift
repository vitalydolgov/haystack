import Foundation
import TransactionalMacro

struct EditTransfer {
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
        guard amount != 0 else { throw TransferError.invalidAmount }
        guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: id) else {
            throw TransferError.notFound
        }

        // choose current leg
        var (currentTx, counterpartTx): (Transaction, Transaction)
        switch accountID {
        case fromLeg.accountID:
            (currentTx, counterpartTx) = (fromLeg, toLeg)
        case toLeg.accountID:
            (currentTx, counterpartTx) = (toLeg, fromLeg)
        default:
            throw TransactionError.notFound
        }

        // update transactions
        try currentTx.update(
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        try counterpartTx.update(
            date: date.asYearMonthDay(),
            amount: -amount,
            notes: notes
        )
        try await store.transactions.save(currentTx)
        try await store.transactions.save(counterpartTx)

        // replace outgoing leg
        guard var fromAccount = try await store.accounts.query(id: fromLeg.accountID) else {
            throw AccountError.notFound
        }
        fromAccount -= fromLeg
        fromAccount += fromLeg.accountID == currentTx.accountID ? currentTx : counterpartTx
        try await store.accounts.save(fromAccount)

        // replace incoming leg
        guard var toAccount = try await store.accounts.query(id: toLeg.accountID) else {
            throw AccountError.notFound
        }
        toAccount -= toLeg
        toAccount += toLeg.accountID == currentTx.accountID ? currentTx : counterpartTx
        try await store.accounts.save(toAccount)
    }
}
