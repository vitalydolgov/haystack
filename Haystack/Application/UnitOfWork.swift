import Foundation

protocol UnitOfWork: Sendable {
    func commit() async throws
    func rollback() async
}
