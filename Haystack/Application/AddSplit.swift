import Foundation
import TransactionalMacro

struct AddSplit {
    let unitOfWork: UnitOfWork

    static func canExecute(
        _ transaction: Transaction,
        parts: [Transaction]
    ) -> Bool {
        do {
            try Split.validate(draft: transaction, parts: parts)
            return true
        } catch {
            return false
        }
    }

    // TODO: refactor with apply method
    @Transactional
    func execute(
        _ transaction: Transaction,
        parts: [Transaction]
    ) async throws -> (Transaction, [Transaction]) {
        guard Self.canExecute(transaction, parts: parts) else {
            throw ApplicationError.cannotExecute
        }

        // load the account
        guard var account = try await store.accounts.query(id: transaction.accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }

        // build the total
        let splitID = UUID()
        let total = try Transaction(
            id: splitID,
            accountID: transaction.accountID,
            date: transaction.date,
            amount: transaction.amount,
            notes: transaction.notes,
            type: .split(splitID)
        )

        var counterparts: [UUID: Account] = [:]
        var counterpartLegs: [Transaction] = []

        func part(from transaction: Transaction) async throws -> Transaction {
            switch transaction.type {
            case .standard:
                return try AddTransaction.apply(
                    account: &account,
                    date: Transaction.date(from: transaction.date),
                    amount: transaction.amount,
                    notes: transaction.notes,
                    splitID: splitID
                )
            case .transfer:
                var counterpart: Account
                if let cached = counterparts[transaction.accountID] {
                    counterpart = cached
                } else if let loaded = try await store.accounts.query(id: transaction.accountID) {
                    counterpart = loaded
                } else {
                    throw AccountError.notFound
                }
                var (leg, counterpartLeg) = try AddTransfer.apply(
                    account: &account,
                    counterpartAccount: &counterpart,
                    date: Transaction.date(from: transaction.date),
                    amount: transaction.amount,
                    notes: transaction.notes
                )
                counterparts[counterpart.id] = counterpart
                leg.wrap(in: splitID)
                counterpartLegs.append(counterpartLeg)
                return leg
            case .split, .splitPart:
                throw SplitError.malformed
            }
        }

        // build the parts
        var composition: [Transaction] = []
        for transaction in parts {
            composition.append(try await part(from: transaction))
        }

        // save the changes
        try Split.validate(total: total, parts: composition)  // TODO: check counterpart legs as well
        try await store.accounts.save(account)
        try await store.accounts.save(batch: Array(counterparts.values))
        try await store.transactions.save(total)
        try await store.transactions.save(batch: composition + counterpartLegs)

        return (total, composition)
    }
}
