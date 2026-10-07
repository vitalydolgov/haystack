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
        guard var account = try await store.accounts.query(id: total.accountID) else {
            throw AccountError.notFound
        }

        var counterparts: [UUID: Account] = [:]
        var deleted: [DeletedTransaction] = []

        // reverse the parts
        for part in parts {
            switch part.type {
            case .splitPart(_, .standard):
                let deletedPart = DeleteTransaction.apply(account: &account, transaction: part, at: date)
                deleted.append(deletedPart)
            case .splitPart(_, .transfer(let transferID)):
                guard let (leg, counterpartLeg) = try await store.transactions.queryTransfer(
                    id: transferID,
                    relativeTo: account.id
                ) else {
                    throw TransferError.notFound
                }
                guard leg.id == part.id else {
                    throw SplitError.malformed
                }
                var counterpartAccount: Account
                if let cached = counterparts[counterpartLeg.accountID] {
                    counterpartAccount = cached
                } else if let loaded = try await store.accounts.query(id: counterpartLeg.accountID) {
                    counterpartAccount = loaded
                } else {
                    throw AccountError.notFound
                }
                let (deletedLeg, deletedCounterpartLeg) = DeleteTransfer.apply(
                    account: &account,
                    counterpartAccount: &counterpartAccount,
                    transaction: leg,
                    counterpartTransaction: counterpartLeg,
                    at: date
                )
                counterparts[counterpartAccount.id] = counterpartAccount
                deleted.append(deletedLeg)
                deleted.append(deletedCounterpartLeg)
            case .standard, .transfer, .split, .splitPart:
                throw SplitError.malformed
            }
        }

        // save the changes
        try await store.accounts.save(account)
        try await store.accounts.save(batch: Array(counterparts.values))
        try await store.transactions.delete(total.delete(at: date))
        try await store.transactions.delete(batch: deleted)
    }
}
