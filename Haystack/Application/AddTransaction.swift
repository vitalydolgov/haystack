import Foundation

struct AddTransaction {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    static func canExecute(accountID: UUID, amount: Decimal, date: Date) -> Bool {
        amount != 0
    }

    func execute(
        accountID: UUID,
        date: Date = .now,
        amount: Decimal,
        notes: String = ""
    ) async throws -> Transaction {
        guard let account = await accounts.find(id: accountID) else {
            throw AccountError.notFound
        }
        guard !account.isClosed else { throw AccountError.closed }
        let transaction = try Transaction(
            accountID: accountID,
            date: date,
            amount: amount,
            notes: notes
        )
        try await transactions.save(transaction)
        return transaction
    }
}
