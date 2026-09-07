import Foundation

protocol UnitOfWork: Sendable {
    var accounts: any AccountRepository { get }
    var transactions: any TransactionRepository { get }

    func perform<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T
}
