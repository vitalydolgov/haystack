import Foundation
import TransactionalMacro

struct ReduceSplit {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal, parts: [Transaction]) -> Bool {
        guard amount != 0 else { return false }
        switch parts.count {
        case 0:
            return true
        case 1:
            return parts[0].amount == amount
        default:
            return false
        }
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

        for part in currentParts {
            guard case .splitPart(let partSplitID, .standard) = part.type, partSplitID == id else {
                throw SplitError.malformed
            }
        }

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

        var removedParts: [DeletedTransaction] = []
        for transaction in currentParts {
            guard var account = accounts[transaction.accountID] else { throw AccountError.notFound }
            let removed = DeleteTransaction.apply(account: &account, transaction: transaction)
            removedParts.append(removed)
            accounts[account.id] = account
        }

        let converted = try Transaction(
            id: currentTotal.id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: .standard
        )
        guard var destination = accounts[accountID] else { throw AccountError.notFound }
        destination += converted
        accounts[destination.id] = destination

        try await store.accounts.save(batch: Array(accounts.values))
        try await store.transactions.save(converted)
        try await store.transactions.delete(batch: removedParts)
    }
}
