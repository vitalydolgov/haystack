import Foundation

struct AddAccount {
    private let accounts: AccountRepository
    private let transactions: TransactionRepository

    init(accounts: AccountRepository, transactions: TransactionRepository) {
        self.accounts = accounts
        self.transactions = transactions
    }

    static func canExecute(name: String, type: AccountType?, balance: Decimal?) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && type != nil && balance != nil
    }

    func execute(
        name: String,
        type: AccountType,
        notes: String = "",
        balance: Decimal = 0,
        on date: Date = .now
    ) async throws -> Account {
        let account = try Account(name: name, type: type, notes: notes)
        try await accounts.save(account)
        if balance != 0 {
            try await transactions.save(
                Transaction(accountID: account.id, date: date, amount: balance, type: .adjustment)
            )
        }
        return account
    }
}
