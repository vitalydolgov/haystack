import Foundation
import TransactionalMacro

struct AddSplit {
    let unitOfWork: UnitOfWork

    private static func validate(_ transaction: Transaction, parts: [Transaction]) throws {
        guard transaction.type == .standard else {
            throw SplitError.malformed
        }
        guard parts.count == Set(parts.map(\.id)).count, parts.count >= 2 else {
            throw SplitError.malformed
        }
        for part in parts {
            switch part.type {
            case .standard:
                guard part.accountID == transaction.accountID else { throw SplitError.malformed }
            case .transfer:
                guard part.accountID != transaction.accountID else { throw SplitError.malformed }
            case .split, .splitPart:
                throw SplitError.malformed
            }
        }
        guard parts.reduce(Decimal(0), { $0 + $1.amount }) == transaction.amount else {
            throw SplitError.invalidAmount
        }
    }

    static func canExecute(_ transaction: Transaction, parts: [Transaction]) -> Bool {
        do {
            try validate(transaction, parts: parts)
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
        try Self.validate(transaction, parts: parts)

        // load the account
        guard var source = try await store.accounts.query(id: transaction.accountID) else {
            throw AccountError.notFound
        }
        guard !source.isClosed else { throw AccountError.closed }

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

        var others: [UUID: Account] = [:]
        var counterparts: [Transaction] = []

        func part(from transaction: Transaction) async throws -> Transaction {
            switch transaction.type {
            case .standard:
                return try AddTransaction.apply(
                    account: &source,
                    date: Transaction.date(from: transaction.date),
                    amount: transaction.amount,
                    notes: transaction.notes,
                    splitID: splitID
                )
            case .transfer:
                var other: Account
                if let cached = others[transaction.accountID] {
                    other = cached
                } else if let loaded = try await store.accounts.query(id: transaction.accountID) {
                    other = loaded
                } else {
                    throw AccountError.notFound
                }
                let date = Transaction.date(from: transaction.date)
                let magnitude = abs(transaction.amount)
                let fromLeg: Transaction
                let toLeg: Transaction
                if transaction.amount < 0 {
                    (fromLeg, toLeg) = try AddTransfer.apply(
                        fromAccount: &source,
                        toAccount: &other,
                        date: date,
                        magnitude: magnitude,
                        notes: transaction.notes
                    )
                } else {
                    (fromLeg, toLeg) = try AddTransfer.apply(
                        fromAccount: &other,
                        toAccount: &source,
                        date: date,
                        magnitude: magnitude,
                        notes: transaction.notes
                    )
                }
                others[other.id] = other
                let counterpart = fromLeg.accountID == other.id ? fromLeg : toLeg
                counterparts.append(counterpart)
                return fromLeg.accountID == source.id ? fromLeg : toLeg
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
        try await store.accounts.save(source)
        try await store.accounts.save(batch: Array(others.values))
        try await store.transactions.save(total)
        try await store.transactions.save(batch: composition + counterparts)

        return (total, composition)
    }
}
