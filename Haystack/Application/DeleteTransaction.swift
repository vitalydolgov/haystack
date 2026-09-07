import Foundation

struct DeleteTransaction {
    private let transactions: TransactionRepository

    init(transactions: TransactionRepository) {
        self.transactions = transactions
    }

    func execute(id: UUID, at date: Date = .now) async throws {
        guard let transaction = await transactions.find(id: id) else {
            throw TransactionError.notFound
        }
        try await transactions.delete(transaction.delete(at: date))
    }
}
