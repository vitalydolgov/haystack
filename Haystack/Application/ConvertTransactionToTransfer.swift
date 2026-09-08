import Foundation
import TransactionalMacro

struct ConvertTransactionToTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal) -> Bool {
        amount != 0
    }

    @Transactional
    func execute(
        id: UUID,
        accountID: UUID,
        transferAccountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard accountID != transferAccountID else {
            throw TransferError.sameAccount
        }
        guard let existing = await store.transactions.find(id: id),
              existing.accountID == accountID,
              existing.type == .standard else {
            throw TransactionError.notFound
        }
        guard let account = await store.accounts.find(id: accountID) else {
            throw AccountError.notFound
        }
        guard let transferAccount = await store.accounts.find(id: transferAccountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        guard !transferAccount.isClosed else { throw AccountError.closed }
        let transferID = UUID()
        let converted = try Transaction(
            id: existing.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: .transfer,
            transferID: transferID
        )
        let counterpart = try Transaction(
            accountID: transferAccountID,
            date: date.asYearMonthDay(),
            amount: -amount,
            notes: notes,
            type: .transfer,
            transferID: transferID
        )
        try await store.transactions.save(converted)
        try await store.transactions.save(counterpart)
    }
}
