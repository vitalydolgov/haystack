import Foundation

struct Store: Sendable {
    let accounts: any AccountRepository
    let transactions: any TransactionRepository
}

protocol UnitOfWork: Sendable {
    var store: Store { get }

    func perform<T: Sendable>(_ work: @Sendable (Store) async throws -> T) async throws -> T
}
