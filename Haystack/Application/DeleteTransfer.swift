import Foundation
import TransactionalMacro

struct DeleteTransfer {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let (fromLeg, toLeg) = try await store.transactions.queryTransfer(id: id) else {
            throw TransferError.notFound
        }

        // remove outgoing leg
        guard var fromAccount = try await store.accounts.query(id: fromLeg.accountID) else {
            throw AccountError.notFound
        }
        fromAccount -= fromLeg
        try await store.accounts.save(fromAccount)
        try await store.transactions.delete(fromLeg.delete(at: date))

        // remove incoming leg
        guard var toAccount = try await store.accounts.query(id: toLeg.accountID) else {
            throw AccountError.notFound
        }
        toAccount -= toLeg
        try await store.accounts.save(toAccount)
        try await store.transactions.delete(toLeg.delete(at: date))
    }
}
