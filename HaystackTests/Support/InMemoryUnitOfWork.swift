import Foundation
@testable import Haystack

struct InMemoryUnitOfWork: UnitOfWork {
    @TaskLocal private static var isPerforming = false

    let store: Store
    private let accounts: InMemoryAccountRepository
    private let transactions: InMemoryTransactionRepository

    init(
        accounts: InMemoryAccountRepository = InMemoryAccountRepository(),
        transactions: InMemoryTransactionRepository = InMemoryTransactionRepository()
    ) {
        self.accounts = accounts
        self.transactions = transactions
        self.store = Store(accounts: accounts, transactions: transactions)
    }

    func perform<T: Sendable>(_ work: @Sendable (Store) async throws -> T) async throws -> T {
        if Self.isPerforming {
            return try await work(store)
        }
        let accountsSnapshot = await accounts.snapshot()
        let transactionsSnapshot = await transactions.snapshot()
        return try await Self.$isPerforming.withValue(true) {
            do {
                return try await work(store)
            } catch {
                await accounts.restore(accountsSnapshot)
                await transactions.restore(transactionsSnapshot)
                throw error
            }
        }
    }
}
