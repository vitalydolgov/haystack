import Foundation
@testable import Haystack

actor InMemoryTransactionRepository: TransactionRepository {
    private var transactions: [UUID: Transaction] = [:]
    private var tombstones: [UUID: DeletedTransaction] = [:]

    func save(_ transaction: Transaction) {
        guard tombstones[transaction.id] == nil else { return }
        transactions[transaction.id] = transaction
    }

    func find(id: UUID) -> Transaction? {
        transactions[id]
    }

    func find(accountID: UUID) -> [Transaction] {
        transactions.values.filter { $0.accountID == accountID }
    }

    func delete(_ transaction: DeletedTransaction) {
        guard tombstones[transaction.id] == nil else { return }
        transactions[transaction.id] = nil
        tombstones[transaction.id] = transaction
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
