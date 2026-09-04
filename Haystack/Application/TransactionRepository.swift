import Foundation

protocol TransactionRepository: Sendable {
    func save(_ transaction: Transaction) async throws
    func find(id: UUID) async -> Transaction?
    func find(accountID: UUID) async -> [Transaction]
    func delete(_ transaction: DeletedTransaction) async throws
}
