import Foundation

enum TransactionQuery: Sendable {
    case account(UUID)
    case all
}

protocol TransactionQuerying: Sendable {
    func query(id: UUID) async throws -> Transaction?
    func query(_ query: TransactionQuery) async throws -> [Transaction]
    func queryTransfer(id: UUID) async throws -> (Transaction, Transaction)?
    func queryCounterpart(transactionID: UUID) async throws -> Transaction?
}

protocol TransactionRepository: TransactionQuerying, Sendable {
    func save(_ transaction: Transaction) async throws
    func delete(_ transaction: DeletedTransaction) async throws
}
