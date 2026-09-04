import Foundation

struct AdjustBalance {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    func stage(id: UUID, to balance: Decimal, on date: Date = .now) async throws -> Transaction? {
        guard let account = await accounts.find(id: id) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        let existing = await transactions.find(accountID: id)
        let delta = balance - account.balance(existing)
        guard delta != 0 else { return nil }
        return try Transaction(accountID: id, date: date, amount: delta, type: .adjustment)
    }

    func execute(id: UUID, to balance: Decimal, on date: Date = .now) async throws {
        if let transaction = try await stage(id: id, to: balance, on: date) {
            try await transactions.save(transaction)
        }
    }
}
