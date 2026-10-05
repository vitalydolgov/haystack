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

        // reverse the parts
        var deleted: [DeletedTransaction] = []
        for part in parts {
            switch part.type {
            case .splitPart(_, .standard):
                source -= part
                deleted.append(part.delete(at: date))
            case .splitPart(_, .transfer(let transferID)):
                guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: transferID) else {
                    throw TransferError.notFound
                }
                let counterpart = if fromLeg.id == part.id {
                    toLeg
                } else if toLeg.id == part.id {
                    fromLeg
                } else {
                    throw SplitError.malformed
                }
                guard var other = try await store.accounts.query(id: counterpart.accountID) else {
                    throw AccountError.notFound
                }
                source -= part
                other -= counterpart
                try await store.accounts.save(other)
                deleted.append(part.delete(at: date))
                deleted.append(counterpart.delete(at: date))
            case .standard, .transfer, .split, .splitPart:
                throw SplitError.malformed
            }
        }

        // remove the split
        deleted.append(total.delete(at: date))
        try await store.accounts.save(source)
        try await store.transactions.delete(batch: deleted)
    }
}
