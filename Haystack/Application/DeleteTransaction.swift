import Foundation

struct DeleteTransaction {
    let unitOfWork: UnitOfWork

    func execute(id: UUID, at date: Date = .now) async throws {
        try await unitOfWork.perform { store in
            guard let transaction = await store.transactions.find(id: id) else {
                throw TransactionError.notFound
            }
            try await store.transactions.delete(transaction.delete(at: date))
        }
    }
}
