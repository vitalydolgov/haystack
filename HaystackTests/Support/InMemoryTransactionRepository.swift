import Foundation
@testable import Haystack

actor InMemoryTransactionRepository: TransactionRepository {
    private var transactions: [UUID: Transaction] = [:]
    private var tombstones: [UUID: DeletedTransaction] = [:]

    func save(_ transaction: Transaction) {
        guard tombstones[transaction.id] == nil else { return }
        transactions[transaction.id] = transaction
    }

    func save(batch: [Transaction]) {
        for transaction in batch {
            save(transaction)
        }
    }

    func query(id: UUID) -> Transaction? {
        transactions[id]
    }

    func query(_ query: TransactionQuery) -> [Transaction] {
        switch query {
        case .account(let accountID):
            transactions.values
                .filter { $0.accountID == accountID }
                .sorted { Transaction.date(from: $0.date) > Transaction.date(from: $1.date) }
        case .all:
            Array(transactions.values)
        }
    }

    func queryTransfer(id: UUID) -> (Transaction, Transaction)? {
        let legs = transactions.values.filter { $0.type.transferID == id && tombstones[$0.id] == nil }
        guard legs.count == 2,
              let outflow = legs.first(where: { $0.amount < 0 }),
              let inflow = legs.first(where: { $0.amount > 0 }) else {
            return nil
        }
        return (outflow, inflow)
    }

    func queryCounterpart(transactionID: UUID) async throws -> Transaction? {
        guard let transaction = query(id: transactionID),
              let transferID = transaction.type.transferID,
              let (leg, counterpartLeg) = try await queryTransfer(id: transferID, relativeTo: transaction.accountID),
              leg.id == transaction.id else { return nil }
        return counterpartLeg
    }

    func querySplit(id: UUID) -> (Transaction, [Transaction])? {
        let members = transactions.values.filter { $0.type.splitID == id && tombstones[$0.id] == nil }
        let totals = members.filter {
            if case .split = $0.type { true } else { false }
        }
        guard totals.count == 1, let total = totals.first else { return nil }
        let parts = members.filter {
            if case .splitPart = $0.type { true } else { false }
        }
        return (total, parts)
    }

    func delete(_ transaction: DeletedTransaction) {
        guard tombstones[transaction.id] == nil else { return }
        transactions[transaction.id] = nil
        tombstones[transaction.id] = transaction
    }

    func delete(batch: [DeletedTransaction]) {
        for transaction in batch {
            delete(transaction)
        }
    }

    func deleted(id: UUID) -> DeletedTransaction? {
        tombstones[id]
    }

    func all() -> [Transaction] {
        Array(transactions.values)
    }

    func snapshot() -> ([UUID: Transaction], [UUID: DeletedTransaction]) {
        (transactions, tombstones)
    }

    func restore(_ snapshot: ([UUID: Transaction], [UUID: DeletedTransaction])) {
        (transactions, tombstones) = snapshot
    }
}
