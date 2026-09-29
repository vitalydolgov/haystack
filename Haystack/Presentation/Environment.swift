import SwiftUI

extension EnvironmentValues {
    @Entry var unitOfWork: any UnitOfWork = MissingUnitOfWork()
    @Entry var accountRepository: any AccountQuerying = MissingAccountRepository()
    @Entry var transactionRepository: any TransactionQuerying = MissingTransactionRepository()
}

private struct MissingUnitOfWork: UnitOfWork {
    var store: Store {
        fatalError("missing environment value unitOfWork")
    }

    func perform<T: Sendable>(_: @Sendable (Store) async throws -> T) async throws -> T {
        fatalError("missing environment value unitOfWork")
    }
}

private struct MissingAccountRepository: AccountQuerying {
    func query(id _: UUID, includeDeleted _: Bool) async throws -> Account? {
        fatalError("missing environment value accountRepository")
    }

    func query(_: AccountQuery) async throws -> [Account] {
        fatalError("missing environment value accountRepository")
    }
}

private struct MissingTransactionRepository: TransactionQuerying {
    func query(id _: UUID) async throws -> Transaction? {
        fatalError("missing environment value transactionRepository")
    }

    func query(_: TransactionQuery) async throws -> [Transaction] {
        fatalError("missing environment value transactionRepository")
    }

    func queryTransfer(id _: UUID) async throws -> (Transaction, Transaction)? {
        fatalError("missing environment value transactionRepository")
    }

    func queryCounterpart(transactionID _: UUID) async throws -> Transaction? {
        fatalError("missing environment value transactionRepository")
    }
}
