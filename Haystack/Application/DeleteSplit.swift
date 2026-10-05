import Foundation
import TransactionalMacro

struct DeleteSplit {
    let unitOfWork: UnitOfWork

    private static func validate(_ total: Transaction, parts: [Transaction]) throws {
        guard case .split(let splitID) = total.type, splitID == total.id else {
            throw SplitError.malformed
        }
        guard Set(parts.map(\.id)).count == parts.count else {
            throw SplitError.malformed
        }
        for part in parts {
            guard part.id != total.id else { throw SplitError.malformed }
            switch part.type {
            case .splitPart(let partSplitID, .standard),
                 .splitPart(let partSplitID, .transfer):
                guard partSplitID == splitID, part.accountID == total.accountID else {
                    throw SplitError.malformed
                }
            case .standard, .transfer, .split, .splitPart:
                throw SplitError.malformed
            }
        }
        let transferIDs = parts.compactMap(\.type.transferID)
        guard Set(transferIDs).count == transferIDs.count else {
            throw SplitError.malformed
        }
        guard parts.reduce(Decimal(0), { $0 + $1.amount }) == total.amount else {
            throw SplitError.invalidAmount
        }
    }

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let (total, parts) = try await store.transactions.querySplit(id: id) else {
            throw TransactionError.notFound
        }
        try Self.validate(total, parts: parts)

        // load the account
        guard var source = try await store.accounts.query(id: total.accountID) else {
            throw AccountError.notFound
        }

        var others: [UUID: Account] = [:]
        var deleted: [DeletedTransaction] = []

        // reverse the parts
        for part in parts {
            switch part.type {
            case .splitPart(_, .standard):
                let deletedPart = DeleteTransaction.apply(account: &source, transaction: part, at: date)
                deleted.append(deletedPart)
            case .splitPart(_, .transfer(let transferID)):
                guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: transferID) else {
                    throw TransferError.notFound
                }
                guard fromLeg.id == part.id || toLeg.id == part.id else {
                    throw SplitError.malformed
                }
                let counterpart = fromLeg.id == part.id ? toLeg : fromLeg
                var other: Account
                if let cached = others[counterpart.accountID] {
                    other = cached
                } else if let loaded = try await store.accounts.query(id: counterpart.accountID) {
                    other = loaded
                } else {
                    throw AccountError.notFound
                }
                let (deletedFrom, deletedTo): (DeletedTransaction, DeletedTransaction)
                if fromLeg.id == part.id {
                    (deletedFrom, deletedTo) = DeleteTransfer.apply(
                        fromAccount: &source,
                        toAccount: &other,
                        fromLeg: fromLeg,
                        toLeg: toLeg,
                        at: date
                    )
                } else {
                    (deletedFrom, deletedTo) = DeleteTransfer.apply(
                        fromAccount: &other,
                        toAccount: &source,
                        fromLeg: fromLeg,
                        toLeg: toLeg,
                        at: date
                    )
                }
                others[other.id] = other
                deleted.append(deletedFrom)
                deleted.append(deletedTo)
            case .standard, .transfer, .split, .splitPart:
                throw SplitError.malformed
            }
        }

        // save the changes
        try await store.accounts.save(source)
        try await store.accounts.save(batch: Array(others.values))
        try await store.transactions.delete(total.delete(at: date))
        try await store.transactions.delete(batch: deleted)
    }
}
