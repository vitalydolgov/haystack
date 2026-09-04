import SwiftData
import SwiftUI

struct AccountTransactionsView: View {
    let accountID: UUID
    @Query private var accounts: [AccountRecord]
    @Query private var transactions: [TransactionRecord]
    @State private var accountToEdit: AccountRecord?

    init(accountID: UUID) {
        self.accountID = accountID
        let accountID = accountID
        _accounts = Query(
            filter: #Predicate<AccountRecord> { $0.id == accountID && $0.deletedAt == nil }
        )
        _transactions = Query(
            filter: #Predicate<TransactionRecord> {
                $0.accountID == accountID && $0.deletedAt == nil
            },
            sort: [
                SortDescriptor(\.year, order: .reverse),
                SortDescriptor(\.month, order: .reverse),
                SortDescriptor(\.day, order: .reverse),
            ]
        )
    }

    private var account: AccountRecord? {
        accounts.first
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        List {
            if let account {
                Section {
                    Text(balance, format: .currency(code: currencyCode))
                        .font(.title)
                        .monospacedDigit()
                }

                Section {
                    ForEach(transactions) { transaction in
                        HStack {
                            Text(dateText(transaction))
                            Spacer()
                            Text(transaction.amount, format: .currency(code: currencyCode))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(account?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let account {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Edit Account") {
                        accountToEdit = account
                    }
                }
            }
        }
        .sheet(item: $accountToEdit) { account in
            EditAccountSheet(account: account, balance: balance)
        }
    }

    private var balance: Decimal {
        transactions.reduce(into: 0 as Decimal) { $0 += $1.amount }
    }

    private func dateText(_ transaction: TransactionRecord) -> String {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = transaction.year
        components.month = transaction.month
        components.day = transaction.day
        guard let date = components.date else { return "" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let account = try! Account(name: "Wallet", type: .cash)
    let context = container.mainContext
    context.insert(AccountRecord(account))
    context.insert(
        TransactionRecord(
            try! Transaction(
                accountID: account.id,
                date: (year: 2026, month: 9, day: 1),
                amount: 10
            )
        )
    )
    context.insert(
        TransactionRecord(
            try! Transaction(
                accountID: account.id,
                date: (year: 2026, month: 8, day: 31),
                amount: -3
            )
        )
    )
    try! context.save()
    return NavigationStack {
        AccountTransactionsView(accountID: account.id)
    }
    .modelContainer(container)
}
