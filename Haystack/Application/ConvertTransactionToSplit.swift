import Foundation
import TransactionalMacro

struct ConvertTransactionToSplit {
    let unitOfWork: UnitOfWork

    static func canExecute(amount: Decimal, parts: [Transaction]) -> Bool {
        guard amount != 0, parts.count >= 2 else { return false }
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

        guard let transaction = try await store.transactions.query(id: id),
              case .standard = transaction.type else {
            throw TransactionError.notFound
        }

        guard let account = try await store.accounts.query(id: transaction.accountID) else {
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

        for part in parts {
            guard part.type == .standard else { throw SplitError.malformed }
        }

        guard var source = accounts[transaction.accountID] else { throw AccountError.notFound }
        source -= transaction
        accounts[source.id] = source

        let total = try Transaction(
            id: id,
            accountID: accountID,
            date: date.asYearMonthDay(),
            amount: amount,
            notes: notes,
            type: .split(id)
        )

        var createdParts: [Transaction] = []
        for part in parts {
            guard var destination = accounts[accountID] else { throw AccountError.notFound }
            let created = try AddTransaction.apply(
                account: &destination,
                date: date,
                amount: part.amount,
                notes: part.notes,
                splitID: id
            )
            accounts[destination.id] = destination
            createdParts.append(created)
        }

        try Split.validate(total: total, parts: createdParts)
        try await store.accounts.save(batch: Array(accounts.values))
        try await store.transactions.save(total)
        try await store.transactions.save(batch: createdParts)
    }
}
