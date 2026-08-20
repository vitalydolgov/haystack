import Foundation

struct AddAccount {
    private let accounts: AccountRepository

    init(accounts: AccountRepository) {
        self.accounts = accounts
    }

    static func canExecute(name: String, type: AccountType?, balance: Decimal?) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !name.isEmpty && type != nil && balance != nil
    }

    func execute(name: String, type: AccountType, notes: String = "", balance: Decimal = 0) async throws -> Account {
        let account = try Account(name: name, type: type, notes: notes, balance: balance)
        try await accounts.save(account)
        return account
    }
}
