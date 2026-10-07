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
    func querySplit(id: UUID) async throws -> (Transaction, [Transaction])?
}

extension TransactionQuerying {
    func queryTransfer(id: UUID, relativeTo accountID: UUID) async throws -> (Transaction, Transaction)? {
        guard let (outflow, inflow) = try await queryTransfer(id: id) else { return nil }
        let leg: Transaction
        let counterpartLeg: Transaction
        if outflow.accountID == accountID {
            leg = outflow
            counterpartLeg = inflow
        } else if inflow.accountID == accountID {
            leg = inflow
            counterpartLeg = outflow
        } else {
            return nil
        }
        return (leg, counterpartLeg)
    }
}

protocol TransactionRepository: TransactionQuerying, Sendable {
    func save(_ transaction: Transaction) async throws
    func save(batch: [Transaction]) async throws
    func delete(_ transaction: DeletedTransaction) async throws
    func delete(batch: [DeletedTransaction]) async throws
}
