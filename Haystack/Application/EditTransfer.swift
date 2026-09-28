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
        var (current, counterpart): (Transaction, Transaction)
        switch accountID {
        case fromLeg.accountID:
            (current, counterpart) = (fromLeg, toLeg)
        case toLeg.accountID:
            (current, counterpart) = (toLeg, fromLeg)
        default:
            throw TransactionError.notFound
        }
        try current.update(
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes
        )
        try counterpart.update(
            date: date.asYearMonthDay(),
            amount: -amount,
            notes: notes
        )
        try await store.transactions.save(current)
        try await store.transactions.save(counterpart)
    }
}
