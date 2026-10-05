import Foundation
import TransactionalMacro

struct ConvertTransactionToTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(accountID: UUID, counterpartAccountID: UUID, amount: Decimal) -> Bool {
        accountID != counterpartAccountID && amount != 0
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        id: UUID,
        accountID: UUID,
        counterpartAccountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        // TODO: guard with canExecute
        // TODO: check invariants before saving
        guard amount != 0 else { throw TransactionError.invalidAmount }
        guard accountID != counterpartAccountID else {
            throw TransferError.sameAccount
        }

        // remove old transaction
        guard let transaction = try await store.transactions.query(id: id),
              case .standard = transaction.type else {
            throw TransactionError.notFound
        }
        guard var transactionAccount = try await store.accounts.query(id: transaction.accountID) else {
            throw AccountError.notFound
        }
        transactionAccount -= transaction
        try await store.accounts.save(transactionAccount)

        // make transfer legs
        let transferID = UUID()
        let convertedTx = try Transaction(
            id: id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: .transfer(transferID)
        )
        let counterpartTx = try Transaction(
            accountID: counterpartAccountID,
            date: date.asYearMonthDay(),
            amount: -amount,
            notes: notes,
            type: .transfer(transferID)
        )

        // update account balance
        guard var account = try await store.accounts.query(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        account += convertedTx
        try await store.accounts.save(account)
        try await store.transactions.save(convertedTx)

        // update counterpart balance
        guard var counterpartAccount = try await store.accounts.query(id: counterpartAccountID) else {
            throw AccountError.notFound
        }
        guard !counterpartAccount.isClosed else { throw AccountError.closed }
        counterpartAccount += counterpartTx
        try await store.accounts.save(counterpartAccount)
        try await store.transactions.save(counterpartTx)
    }
}
