import Foundation
@testable import Haystack

actor InMemoryTransactionRepository: TransactionRepository {
    private var transactions: [UUID: Transaction] = [:]
    private var tombstones: [UUID: DeletedTransaction] = [:]

    func save(_ transaction: Transaction) {
        guard tombstones[transaction.id] == nil else { return }
        transactions[transaction.id] = transaction
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
        guard legs.count == 2 else { return nil }
        let fromLeg = legs.first { $0.amount < 0 }
        let toLeg = legs.first { $0.amount > 0 }
        guard let fromLeg = fromLeg, let toLeg = toLeg else { return nil }
        return (fromLeg, toLeg)
    }

    func queryCounterpart(transactionID: UUID) -> Transaction? {
        guard let transaction = query(id: transactionID),
              let transferID = transaction.type.transferID,
              let (fromLeg, toLeg) = queryTransfer(id: transferID) else { return nil }
        if fromLeg.id == transaction.id { return toLeg }
        if toLeg.id == transaction.id { return fromLeg }
        return nil
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
