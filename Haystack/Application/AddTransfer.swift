import Foundation
import TransactionalMacro

struct AddTransfer {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date = .now,
        amount: Decimal,
        notes: String = ""
    ) async throws -> (Transaction, Transaction) {
        guard fromAccountID != toAccountID else {
            throw TransferError.sameAccount
        }

        // make transfer legs
        let transferID = UUID()
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let fromLeg = try Transaction(
            accountID: fromAccountID,
            date: (year: components.year!, month: components.month!, day: components.day!),
            amount: -amount,
            notes: notes,
            type: .transfer,
            transferID: transferID
        )
        let toLeg = try Transaction(
            accountID: toAccountID,
            date: (year: components.year!, month: components.month!, day: components.day!),
            amount: amount,
            notes: notes,
            type: .transfer,
            transferID: transferID
        )

        // add outgoing leg
        guard var fromAccount = try await store.accounts.query(id: fromAccountID) else {
            throw AccountError.notFound
        }
        guard !fromAccount.isClosed else { throw AccountError.closed }
        fromAccount += fromLeg
        try await store.accounts.save(fromAccount)
        try await store.transactions.save(fromLeg)

        // add incoming leg
        guard var toAccount = try await store.accounts.query(id: toAccountID) else {
            throw AccountError.notFound
        }
        guard !toAccount.isClosed else { throw AccountError.closed }
        toAccount += toLeg
        try await store.accounts.save(toAccount)
        try await store.transactions.save(toLeg)

        return (fromLeg, toLeg)
    }
}
