import SwiftData
import SwiftUI

struct TransactionsView: View {
    let accountID: UUID
    @Query private var accounts: [AccountRecord]
    @Query private var transactions: [TransactionRecord]
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(Navigator.self) private var navigator

    @State private var deletingTransaction: TransactionRecord?
    @State private var deleteID: UUID?

    init(accountID: UUID) {
        self.accountID = accountID
        _accounts = Query(
            filter: #Predicate<AccountRecord> { $0.id == accountID }
        )
        _transactions = Query(
            filter: #Predicate<TransactionRecord> {
                $0.accountID == accountID && $0.deletedAt == nil
            },
            sort: [SortDescriptor(\.packedDate, order: .reverse)]
        )
    }

    private var accountName: String {
        accounts.first?.name ?? ""
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
                    if let transferID = transaction.transferID {
                        navigator.present(
                            .editTransfer(accountID: accountID, transferID: transferID)
                        )
                    } else {
                        navigator.present(
                            .editTransaction(accountID: accountID, transactionID: transaction.id)
                        )
                    }
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
        .task {
            #if DEBUG
            print("navigation \(Self.self) accountID=\(accountID)")
            #endif
        }
        .navigationTitle(accountName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // TODO: edit account
            // TODO: select
            // TODO: search
            // TODO: reconcile
            // TODO: hide/show reconciled
            ToolbarItem(placement: .primaryAction) {
                Button("Add Transaction", systemImage: "plus") {
                    navigator.present(.addTransaction(accountID: accountID))
                }
            }
        }
    }

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { deletingTransaction != nil },
            set: { if !$0 { deletingTransaction = nil } }
        )
    }

    private func delete(id: UUID) async {
        guard let unitOfWork else { return }
        do {
            try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: id)
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
