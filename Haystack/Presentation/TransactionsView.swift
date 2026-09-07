import SwiftData
import SwiftUI

struct TransactionsView: View {
    let account: AccountRecord
    @Query private var transactions: [TransactionRecord]
    @Environment(\.transactionRepository) private var transactionRepository

    @State private var deletingTransaction: TransactionRecord?
    @State private var deleteID: UUID?
    @State private var isAddingTransaction = false
    @State private var editingTransaction: TransactionRecord?

    init(account: AccountRecord) {
        self.account = account
        let accountID = account.id
        _transactions = Query(
            filter: #Predicate<TransactionRecord> {
                $0.accountID == accountID && $0.deletedAt == nil
            },
            sort: [SortDescriptor(\.packedDate, order: .reverse)]
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
                .contentShape(Rectangle())
                .onTapGesture {
                    editingTransaction = transaction
                }
                .swipeActions(edge: .leading) {
                    // TODO: clear/unclear
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deletingTransaction = transaction
                    }
                }
                .contextMenu {
                    // TODO: move
                    // TODO: clear/unclear
                    // TODO: duplicate
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        deletingTransaction = transaction
                    }
                }
            }
        }
        .alert("Delete Transaction", isPresented: isConfirmingDelete, presenting: deletingTransaction) { transaction in
            Button("Delete", role: .destructive) {
                deleteID = transaction.id
            }
        } message: { _ in
            Text("Do you really want to delete this transaction?")
        }
        .task(id: deleteID) {
            guard let deleteID else { return }
            await delete(id: deleteID)
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
                    isAddingTransaction = true
                }
            }
        }
        .sheet(isPresented: $isAddingTransaction) {
            TransactionSheet(accountID: account.id, mode: .add)
        }
        .sheet(item: $editingTransaction) { transaction in
            TransactionSheet(accountID: account.id, mode: .edit(transaction.id))
        }
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { deletingTransaction != nil },
            set: { if !$0 { deletingTransaction = nil } }
        )
    }

    private func delete(id: UUID) async {
        guard let transactionRepository else { return }
        do {
            try await DeleteTransaction(transactions: transactionRepository).execute(id: id)
        } catch {
            deleteID = nil
        }
    }

    private func dateText(_ transaction: TransactionRecord) -> String {
        let date = transaction.unpackedDate
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = date.year
        components.month = date.month
        components.day = date.day
        guard let value = components.date else { return "" }
        return value.formatted(date: .abbreviated, time: .omitted)
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
