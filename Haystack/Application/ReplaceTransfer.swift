import Foundation
import TransactionalMacro

struct ReplaceTransfer {
    let unitOfWork: UnitOfWork

    static func canExecute(fromAccountID: UUID, toAccountID: UUID, amount: Decimal) -> Bool {
        fromAccountID != toAccountID && amount > 0
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        id: UUID,
        fromAccountID: UUID,
        toAccountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = ""
    ) async throws {
        guard Self.canExecute(
            fromAccountID: fromAccountID,
            toAccountID: toAccountID,
            amount: amount
        ) else {
            throw ApplicationError.cannotExecute
        }
        // TODO: check invariants before saving
        guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: id) else {
            throw TransferError.notFound
        }

        var accountsByID: [UUID: Account] = [:]
        let accountIDs = [fromLeg.accountID, toLeg.accountID, fromAccountID, toAccountID]
        for id in accountIDs where accountsByID[id] == nil {
            guard let account = try await store.accounts.query(id: id) else {
                throw AccountError.notFound
            }
            accountsByID[id] = account
        }

        guard var fromAccount = accountsByID[fromLeg.accountID],
              var toAccount = accountsByID[toLeg.accountID] else {
            throw AccountError.notFound
        }
        let (deletedFromLeg, deletedToLeg) = DeleteTransfer.apply(
            account: &fromAccount,
            counterpartAccount: &toAccount,
            transaction: fromLeg,
            counterpartTransaction: toLeg
        )
        accountsByID[fromAccount.id] = fromAccount
        accountsByID[toAccount.id] = toAccount

        guard var nextFromAccount = accountsByID[fromAccountID],
              var nextToAccount = accountsByID[toAccountID] else {
            throw AccountError.notFound
        }
        let (newFromLeg, newToLeg) = try AddTransfer.apply(
            account: &nextFromAccount,
            counterpartAccount: &nextToAccount,
            date: date,
            amount: -amount,
            notes: notes
        )
        accountsByID[nextFromAccount.id] = nextFromAccount
        accountsByID[nextToAccount.id] = nextToAccount

        try await store.accounts.save(batch: Array(accountsByID.values))
        try await store.transactions.delete(deletedFromLeg)
        try await store.transactions.delete(deletedToLeg)
        try await store.transactions.save(newFromLeg)
        try await store.transactions.save(newToLeg)
    }
}
