import Foundation
import TransactionalMacro

struct AddAccount {
    let unitOfWork: UnitOfWork

    static func canExecute(name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // TODO: refactor with apply method
    @discardableResult
    @Transactional
    func execute(
        name: String,
        type: AccountType,
        notes: String = "",
        balance: Decimal = 0
    ) async throws -> Account {
        var account = try Account(name: name, type: type, notes: notes)
        if balance != 0 {
            let transaction = try Transaction(
                accountID: account.id,
                date: Date.now.asYearMonthDay(),
                amount: balance,
                type: .standard
            )
            account += transaction
            try await store.transactions.save(transaction)
        }
        try await store.accounts.save(account)
        return account
    }
}
