import SwiftUI

struct TransactionsView: View {
    let accountID: UUID

    @State private var transactions: [Transaction] = []
    @State private var accountName = ""
    @State private var deletingTransaction: Transaction?
    @State private var deleteID: UUID?

    @Environment(Navigator.self) private var navigator
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository

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
                    if case .split = transaction.type {
                        Text("Split")
                            .font(.caption.weight(.semibold))
                            .textCase(.uppercase)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .foregroundStyle(.background)
                            .background(DeosaiTheme.straw, in: Capsule())
                    }
                    Spacer()
                    Text(transaction.amount, format: .currency(code: currencyCode))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    // TODO: status
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    navigator.present(
                        .editTransaction(transactionID: transaction.id, transferID: transaction.type.transferID)
                    )
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
            transactions = await transactions()
        }
        .task(id: navigator.sheet) {
            accountName = await accountName()
            transactions = await transactions()
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

    private func accountName() async -> String {
        do {
            guard let account = try await accountRepository.query(id: accountID) else {
                return ""
            }
            return account.name
        } catch {
            print("error: \(error)")
            return ""
        }
    }

    private func transactions() async -> [Transaction] {
        do {
            return try await transactionRepository.query(.account(accountID)).filter { transaction in
                if case .splitPart = transaction.type { false } else { true }
            }
        } catch {
            print("error: \(error)")
            return []
        }
    }

    private func delete(id: UUID) async {
        do {
            guard let transaction = transactions.first(where: { $0.id == id }) else { return }
            switch transaction.type {
            case .standard:
                try await DeleteTransaction(unitOfWork: unitOfWork).execute(id: id)
            case .transfer(let transferID):
                try await DeleteTransfer(unitOfWork: unitOfWork).execute(id: transferID)
            case .split(let splitID):
                try await DeleteSplit(unitOfWork: unitOfWork).execute(id: splitID)
            case .splitPart:
                return
            }
        } catch {
            deleteID = nil
        }
    }

    private func dateText(_ transaction: Transaction) -> String {
        Transaction.date(from: transaction.date).formatted(date: .abbreviated, time: .omitted)
    }
}
