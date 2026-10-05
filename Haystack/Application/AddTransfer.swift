import Foundation
import TransactionalMacro

struct AddTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID, magnitude: Decimal) -> Bool {
        fromAccountID != toAccountID && magnitude > 0
    }

    static func apply(
        fromAccount: inout Account,
        toAccount: inout Account,
        date: Date = .now,
        magnitude: Decimal,
        notes: String = ""
    ) throws -> (Transaction, Transaction) {
        guard fromAccount.id != toAccount.id else { throw TransferError.sameAccount }
        guard !fromAccount.isClosed, !toAccount.isClosed else { throw AccountError.closed }
        let transferID = UUID()
        let day = date.asYearMonthDay()
        let fromLeg = try Transaction(
            accountID: fromAccount.id,
            date: day,
            amount: -magnitude,
            notes: notes,
            type: .transfer(transferID)
        )
        let toLeg = try Transaction(
            accountID: toAccount.id,
            date: day,
            amount: magnitude,
            notes: notes,
            type: .transfer(transferID)
        )
        fromAccount += fromLeg
        toAccount += toLeg
        return (fromLeg, toLeg)
    }

    @Transactional
    func execute(
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date = .now,
        magnitude: Decimal,
        notes: String = ""
    ) async throws -> (Transaction, Transaction) {
        guard var fromAccount = try await store.accounts.query(id: fromAccountID),
              var toAccount = try await store.accounts.query(id: toAccountID) else {
            throw AccountError.notFound
        }
        let (fromLeg, toLeg) = try Self.apply(
            fromAccount: &fromAccount,
            toAccount: &toAccount,
            date: date,
            magnitude: magnitude,
            notes: notes
        )
        try await store.accounts.save(fromAccount)
        try await store.transactions.save(fromLeg)
        try await store.accounts.save(toAccount)
        try await store.transactions.save(toLeg)
        return (fromLeg, toLeg)
    }
}
