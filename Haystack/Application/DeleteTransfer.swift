import Foundation
import TransactionalMacro

struct DeleteTransfer {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let (fromLeg, toLeg) = await store.transactions.findTransfer(id: id) else {
            throw TransferError.notFound
        }
        try await store.transactions.delete(fromLeg.delete(at: date))
        try await store.transactions.delete(toLeg.delete(at: date))
    }
}
