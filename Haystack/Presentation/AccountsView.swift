import SwiftUI

private struct AccountRow: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let type: AccountType
    let balance: Decimal
    let isClosed: Bool

    init(_ account: Account) {
        id = account.id
        name = account.name
        type = account.type
        balance = account.balance
        isClosed = account.isClosed
    }

    static func == (lhs: AccountRow, rhs: AccountRow) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.balance == rhs.balance
            && lhs.isClosed == rhs.isClosed
    }
}

struct AccountsView: View {
    @State private var accounts: [AccountRow] = []
    @State private var pendingCloseID: UUID?

    @Environment(Navigator.self) private var navigator
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.accountRepository) private var accountRepository

    // MARK: Views

    private func accountRow(_ account: AccountRow) -> some View {
        NavigationLink(value: Route.transactions(accountID: account.id)) {
            HStack {
                AccountMarker(type: account.type)
                Text(account.name)
                Spacer()
                Text(account.balance, format: .currency(code: currencyCode))
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
                    if account.balance == 0 {
                        close(id: account.id)
                    } else {
                        pendingCloseID = account.id
                    }
                }
            }
        }
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
                Button("Add Account", systemImage: "folder.badge.plus") {
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
        }
        .task {
            #if DEBUG
            print("navigation \(Self.self)")
            #endif
        }
    }

    // MARK: Tasks

    private func accounts() async -> [AccountRow] {
        do {
            return try await accountRepository.query(.includingClosed).map(AccountRow.init)
        } catch {
            print("error: \(error)")
            return []
        }
    }

    // MARK: Commands

    private func close(id: UUID) {
        Task {
            try await CloseAccount(unitOfWork: unitOfWork).execute(id: id)
            accounts = await accounts()
        }
    }

    private func reopen(id: UUID) {
        Task {
            try await ReopenAccount(unitOfWork: unitOfWork).execute(id: id)
            accounts = await accounts()
        }
    }

    // MARK: Helpers

    private var isConfirmingClose: Binding<Bool> {
        Binding(
            get: { pendingCloseID != nil },
            set: { if !$0 { pendingCloseID = nil } }
        )
    }

    private var openAccounts: [AccountRow] {
        accounts.filter { !$0.isClosed }
    }

    private var closedAccounts: [AccountRow] {
        accounts.filter(\.isClosed)
    }

    // TODO: fetch
    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}
