import SwiftData
import SwiftUI

struct TransactionsView: View {
    let account: AccountRecord
    @Query private var transactions: [TransactionRecord]
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.modelContext) private var modelContext

    @State private var showingDeleteConfirmation = false
    @State private var transactionToDelete: TransactionRecord?

    init(account: AccountRecord) {
        self.account = account
        let accountID = account.id
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

    // TODO: fetch currency code
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        List {
            // TODO: display working balance
            // TODO: display cleared and uncleard balance
            // TODO: grouping by date
            ForEach(transactions) { transaction in
                // TODO: edit transaction sheet
                HStack {
                    // TODO: payee
                    Text(dateText(transaction))
                    Spacer()
                    Text(transaction.amount, format: .currency(code: currencyCode))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    // TODO: status
                }
                .swipeActions(edge: .leading) {
                    // TODO: clear/unclear
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        transactionToDelete = transaction
                        showingDeleteConfirmation = true
                    }
                }
                .contextMenu {
                    // TODO: move
                    // TODO: clear/unclear
                    // TODO: duplicate
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        transactionToDelete = transaction
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {
                transactionToDelete = nil
            }
        } message: {
            Text("Do you really want to delete this transaction?")
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // TODO: edit account
            // TODO: select
            // TODO: search
            // TODO: reconcile
            // TODO: hide/show reconciled
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus") {
                    // TODO: add transaction sheet
                    let transaction = TransactionRecord(
                        id: UUID(),
                        accountID: account.id,
                        type: .standard,
                        year: Calendar.current.component(.year, from: Date()),
                        month: Calendar.current.component(.month, from: Date()),
                        day: Calendar.current.component(.day, from: Date()),
                        amount: -100,
                        notes: "Mock transaction",
                        deletedAt: nil
                    )
                    modelContext.insert(transaction)
                }
            }
        }
    }

    private func delete() {
        guard let transactionRepository, let id = transactionToDelete?.id else { return }
        transactionToDelete = nil
        Task {
            try await DeleteTransaction(transactions: transactionRepository).execute(id: id)
        }
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
    let record = AccountRecord(account)
    let context = container.mainContext
    context.insert(record)
    context.insert(
        TransactionRecord(
            try! Transaction(
                accountID: account.id,
                date: (year: 2026, month: 9, day: 1),
                amount: 10,
                type: .adjustment
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
        TransactionsView(account: record)
    }
    .modelContainer(container)
    .environment(\.transactionRepository, SwiftDataTransactionRepository(modelContainer: container))
}
