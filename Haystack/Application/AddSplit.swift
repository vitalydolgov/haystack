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

        func part(from transaction: Transaction) async throws -> Transaction {
            switch transaction.type {
            case .standard:
                return try Transaction(
                    accountID: transaction.accountID,
                    date: transaction.date,
                    amount: transaction.amount,
                    notes: transaction.notes,
                    type: .splitPart(splitID, transaction.type)
                )
            case .transfer:
                let (fromLeg, toLeg) = try await AddTransfer(unitOfWork: unitOfWork).execute(
                    fromAccountID: transaction.amount < 0 ? source.id : transaction.accountID,
                    toAccountID: transaction.amount < 0 ? transaction.accountID : source.id,
                    date: Transaction.date(from: transaction.date),
                    magnitude: abs(transaction.amount),
                    notes: transaction.notes
                )
                return fromLeg.accountID == source.id ? fromLeg : toLeg
            case .split, .splitPart:
                throw SplitError.malformed
            }
        }

        // build the parts
        var composition: [Transaction] = []
        for transaction in parts {
            let part = try await part(from: transaction)
            source += part
            composition.append(part)
        }

        // save the split
        try await store.transactions.save(total)
        try await store.transactions.save(batch: composition)
        try await store.accounts.save(source)

        return (total, composition)
    }
}
