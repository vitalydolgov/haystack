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
        guard let fromAccount = await store.accounts.find(id: fromAccountID) else {
            throw AccountError.notFound
        }
        guard let toAccount = await store.accounts.find(id: toAccountID) else {
            throw AccountError.notFound
        }
        guard !fromAccount.isClosed else { throw AccountError.closed }
        guard !toAccount.isClosed else { throw AccountError.closed }
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
        try await store.transactions.save(fromLeg)
        try await store.transactions.save(toLeg)
        return (fromLeg, toLeg)
    }
}
