import SwiftUI

struct AccountsView: View {
    @State private var accounts: [Account] = []
    @State private var transactions: [Transaction] = []
    @State private var pendingCloseID: UUID?

    @Environment(Navigator.self) private var navigator
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository

    private var openAccounts: [Account] {
        accounts.filter { !$0.isClosed }
    }

    private var closedAccounts: [Account] {
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
        .task(id: navigator.sheet) {
            accounts = await accounts()
            transactions = await transactions()
        }
        .task {
            #if DEBUG
            print("navigation \(Self.self)")
            #endif
        }
    }

    private func accounts() async -> [Account] {
        do {
            guard let accountRepository else { return [] }
            return try await accountRepository.query(.includingClosed)
        } catch {
            print("error: \(error)")
            return []
        }
    }

    private func transactions() async -> [Transaction] {
        do {
            guard let transactionRepository else { return [] }
            return try await transactionRepository.query(.all)
        } catch {
            print("error: \(error)")
            return []
        }
    }

    private var isConfirmingClose: Binding<Bool> {
        Binding(
            get: { pendingCloseID != nil },
            set: { if !$0 { pendingCloseID = nil } }
        )
    }

    private func accountRow(_ account: Account) -> some View {
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

    private func requestClose(_ account: Account) {
        if balance(for: account) == 0 {
            close(id: account.id)
        } else {
            pendingCloseID = account.id
        }
    }

    private func balance(for account: Account) -> Decimal {
        transactions.reduce(into: 0 as Decimal) { total, transaction in
            guard transaction.accountID == account.id else { return }
            total += transaction.amount
        }
    }

    private func close(id: UUID) {
        guard let unitOfWork else { return }
        Task {
            try await CloseAccount(unitOfWork: unitOfWork).execute(id: id)
            accounts = await accounts()
            transactions = await transactions()
        }
    }

    private func reopen(id: UUID) {
        guard let unitOfWork else { return }
        Task {
            try await ReopenAccount(unitOfWork: unitOfWork).execute(id: id)
            accounts = await accounts()
            transactions = await transactions()
        }
    }
}
