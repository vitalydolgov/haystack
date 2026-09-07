import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(Navigator.self) private var navigator
    @Query(
        filter: #Predicate<AccountRecord> { $0.deletedAt == nil },
        sort: \AccountRecord.name
    )
    private var accounts: [AccountRecord]
    @Query(filter: #Predicate<TransactionRecord> { $0.deletedAt == nil })
    private var transactions: [TransactionRecord]
    @State private var pendingCloseID: UUID?

    private var openAccounts: [AccountRecord] {
        accounts.filter { !$0.isClosed }
    }

    private var closedAccounts: [AccountRecord] {
        accounts.filter(\.isClosed)
    }

    // TODO: fetch
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        List {
            if !openAccounts.isEmpty {
                Section("Cash") {
                    ForEach(openAccounts) { account in
                        accountRow(account)
                    }
                }
            }

            if !closedAccounts.isEmpty {
                Section("Closed") {
                    ForEach(closedAccounts) { account in
                        accountRow(account)
                    }
                }
            }
        }
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Account", systemImage: "plus") {
                    navigator.present(.addAccount)
                }
            }
        }
        .alert("Close Account", isPresented: isConfirmingClose) {
            Button("Adjust Balance & Close") {
                if let pendingCloseID {
                    close(id: pendingCloseID)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Before you can close this account, the balance will have to be zeroed out.")
        }
        .task {
            #if DEBUG
            print("navigation \(Self.self)")
            #endif
        }
    }

    private var isConfirmingClose: Binding<Bool> {
        Binding(
            get: { pendingCloseID != nil },
            set: { if !$0 { pendingCloseID = nil } }
        )
    }

    private func accountRow(_ account: AccountRecord) -> some View {
        NavigationLink(value: Route.transactions(accountID: account.id)) {
            HStack {
                Text(account.name)
                Spacer()
                Text(balance(for: account), format: .currency(code: currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .contextMenu {
            Button("Edit Account") {
                navigator.present(.editAccount(accountID: account.id))
            }
            if account.isClosed {
                Button("Reopen Account") {
                    reopen(id: account.id)
                }
            } else {
                Button("Close Account", role: .destructive) {
                    requestClose(account)
                }
            }
        }
    }

    private func requestClose(_ account: AccountRecord) {
        if balance(for: account) == 0 {
            close(id: account.id)
        } else {
            pendingCloseID = account.id
        }
    }

    private func balance(for account: AccountRecord) -> Decimal {
        transactions.reduce(into: 0 as Decimal) { total, transaction in
            guard transaction.accountID == account.id else { return }
            total += transaction.amount
        }
    }

    private func close(id: UUID) {
        guard let accountRepository, let transactionRepository else { return }
        Task {
            // TODO: unit of work
            try await CloseAccount(accounts: accountRepository, transactions: transactionRepository)
                .execute(id: id)
        }
    }

    private func reopen(id: UUID) {
        guard let accountRepository else { return }
        Task {
            // TODO: unit of work
            try await ReopenAccount(accounts: accountRepository).execute(id: id)
        }
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    let unitOfWork = SwiftDataUnitOfWork(modelContainer: container)
    HaystackView()
        .modelContainer(container)
        .environment(\.unitOfWork, unitOfWork)
        .environment(\.accountRepository, SwiftDataAccountRepository(
            modelContainer: unitOfWork.modelContainer,
            modelExecutor: unitOfWork.modelExecutor
        ))
        .environment(\.transactionRepository, SwiftDataTransactionRepository(modelContainer: container))
}
