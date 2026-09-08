import Foundation
import TransactionalMacro

struct DeleteTransaction {
    let unitOfWork: UnitOfWork

    @Transactional
    func execute(id: UUID, at date: Date = .now) async throws {
        guard let transaction = await store.transactions.find(id: id) else {
            throw TransactionError.notFound
        }
        try await store.transactions.delete(transaction.delete(at: date))
    }
}
// TODO: guard against .transfer transactions
