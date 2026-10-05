import Foundation
import TransactionalMacro

struct DeleteSplit {
    let unitOfWork: UnitOfWork

    // TODO: refactor with apply method
    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        // TODO: check invariants before saving
        guard let (total, parts) = try await store.transactions.querySplit(id: id) else {
            throw TransactionError.notFound
        }

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
                let (deletedPart, deletedCounterpart) = DeleteTransfer.apply(
                    account: &source,
                    counterpartAccount: &other,
                    transaction: part,
                    counterpartTransaction: counterpart,
                    at: date
                )
                others[other.id] = other
                deleted.append(deletedPart)
                deleted.append(deletedCounterpart)
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
