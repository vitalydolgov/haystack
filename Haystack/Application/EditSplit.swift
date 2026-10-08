import Foundation
import TransactionalMacro

struct EditSplit {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal, parts: [Transaction]) -> Bool {
        guard amount != 0 else { return false }
        return parts.reduce(Decimal(0), { $0 + $1.amount }) == amount
    }

    @Transactional
    func execute(
        id: UUID,
        accountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String = "",
        parts: [Transaction]
    ) async throws {
        guard Self.canExecute(amount: amount, parts: parts) else {
            throw ApplicationError.cannotExecute
        }

        guard let (currentTotal, currentParts) = try await store.transactions.querySplit(id: id),
              currentTotal.id == id,
              case .split(let splitID) = currentTotal.type,
              splitID == id else {
            throw TransactionError.notFound
        }

        var currentByID: [UUID: Transaction] = [:]
        for part in currentParts {
            currentByID[part.id] = part
        }
        var added: [Transaction] = []
        var updated: [(current: Transaction, draft: Transaction)] = []
        for part in parts {
            if let current = currentByID[part.id] {
                updated.append((current, part))
            } else {
                added.append(part)
            }
        }
        let draftedIDs = Set(parts.map(\.id))
        let deleted = currentParts.filter { !draftedIDs.contains($0.id) }

        // TODO: transfers

        guard let account = try await store.accounts.query(id: currentTotal.accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        var accounts: [UUID: Account] = [account.id: account]
        if account.id != accountID {
            guard let destination = try await store.accounts.query(id: accountID) else {
                throw AccountError.notFound
            }
            guard !destination.isClosed else { throw AccountError.closed }
            accounts[destination.id] = destination
        }

        var createdParts: [Transaction] = []
        for transaction in added {
            guard transaction.type == .standard else { throw SplitError.malformed }
            guard var account = accounts[accountID] else { throw AccountError.notFound }
            let created = try AddTransaction.apply(
                account: &account,
                date: date,
                amount: transaction.amount,
                notes: transaction.notes,
                splitID: id
            )
            accounts[account.id] = account
            createdParts.append(created)
        }

        var updatedParts: [Transaction] = []
        for (current, draft) in updated {
            guard case .splitPart(let partSplitID, .standard) = current.type, partSplitID == id else {
                throw SplitError.malformed
            }
            let updated: Transaction
            if current.accountID == accountID {
                guard var account = accounts[accountID] else { throw AccountError.notFound }
                updated = try EditTransaction.apply(
                    current,
                    account: &account,
                    date: date,
                    amount: draft.amount,
                    notes: current.notes
                )
                accounts[account.id] = account
            } else {
                guard var account = accounts[current.accountID],
                      var movingToAccount = accounts[accountID] else {
                    throw AccountError.notFound
                }
                updated = try EditTransaction.apply(
                    current,
                    account: &account,
                    movingTo: &movingToAccount,
                    date: date,
                    amount: draft.amount,
                    notes: current.notes
                )
                accounts[account.id] = account
                accounts[movingToAccount.id] = movingToAccount
            }
            updatedParts.append(updated)
        }

        var removedParts: [DeletedTransaction] = []
        for transaction in deleted {
            guard case .splitPart(let partSplitID, .standard) = transaction.type,
                  partSplitID == id else {
                throw SplitError.malformed
            }
            guard var account = accounts[transaction.accountID] else { throw AccountError.notFound }
            let removed = DeleteTransaction.apply(account: &account, transaction: transaction)
            removedParts.append(removed)
            accounts[account.id] = account
        }

        let updatedTotal = try Transaction(
            id: currentTotal.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: .split(id)
        )

        try Split.validate(total: updatedTotal, parts: createdParts + updatedParts)
        try await store.accounts.save(batch: Array(accounts.values))
        try await store.transactions.save(updatedTotal)
        try await store.transactions.save(batch: createdParts)
        try await store.transactions.save(batch: updatedParts)
        try await store.transactions.delete(batch: removedParts)
    }
}
