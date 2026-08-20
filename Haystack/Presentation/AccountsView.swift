import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.accountRepository) private var accountRepository
    @Query(sort: \AccountRecord.name) private var accounts: [AccountRecord]
    @State private var pendingCloseID: UUID?
    @State private var isAddingAccount = false
    @State private var accountToEdit: AccountRecord?

    private var openAccounts: [AccountRecord] {
        accounts.filter { !$0.isClosed }
    }

    private var closedAccounts: [AccountRecord] {
        accounts.filter(\.isClosed)
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    var body: some View {
        NavigationStack {
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
                        isAddingAccount = true
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
            .sheet(isPresented: $isAddingAccount) {
                AddAccountSheet()
            }
            .sheet(item: $accountToEdit) { account in
                EditAccountSheet(account: account)
            }
        }
    }

    private var isConfirmingClose: Binding<Bool> {
        Binding(
            get: { pendingCloseID != nil },
            set: { if !$0 { pendingCloseID = nil } }
        )
    }

    private func accountRow(_ account: AccountRecord) -> some View {
        Button {
            accountToEdit = account
        } label: {
            HStack {
                Text(account.name)
                Spacer()
                Text(account.balance, format: .currency(code: currencyCode))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .contextMenu {
            Button("Edit Account") {
                accountToEdit = account
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
        if account.balance == 0 {
            close(id: account.id)
        } else {
            pendingCloseID = account.id
        }
    }

    private func close(id: UUID) {
        guard let accountRepository else { return }
        Task {
            try await CloseAccount(accounts: accountRepository).execute(id: id)
        }
    }

    private func reopen(id: UUID) {
        guard let accountRepository else { return }
        Task {
            try await ReopenAccount(accounts: accountRepository).execute(id: id)
        }
    }
}

#Preview {
    let container = try! Persistence.makeContainer(inMemory: true)
    AccountsView()
        .modelContainer(container)
        .environment(\.accountRepository, SwiftDataAccountRepository(modelContainer: container))
}
