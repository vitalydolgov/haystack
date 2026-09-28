import Foundation
import TransactionalMacro

struct DeleteTransaction {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let transaction = try await store.transactions.query(id: id) else {
            throw TransactionError.notFound
        }
        guard transaction.type != .transfer else {
            throw TransactionError.invalidType
        }
        try await store.transactions.delete(transaction.delete(at: date))
    }
}
