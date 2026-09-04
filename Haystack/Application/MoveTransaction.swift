import Foundation

struct MoveTransaction {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    static func canExecute(fromAccountID: UUID, toAccountID: UUID) -> Bool {
        fromAccountID != toAccountID
    }

    func execute(id: UUID, toAccountID: UUID) async throws {
        guard let transaction = await transactions.find(id: id) else {
            throw TransactionError.notFound
        }
        guard let targetAccount = await accounts.find(id: toAccountID) else {
            throw AccountError.notFound
        }
        guard !targetAccount.isClosed else {
            throw AccountError.closed
        }
        guard transaction.accountID != toAccountID else { return }

        let moved = try Transaction(
            id: transaction.id,
            accountID: toAccountID,
            date: Transaction.date(from: transaction.date),
            amount: transaction.amount,
            notes: transaction.notes,
            type: transaction.type
        )
        try await transactions.save(moved)
    }
}
