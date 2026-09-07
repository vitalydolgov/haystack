import SwiftUI

struct EditAccountSheet: View {
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

    private let accountID: UUID
    @State private var isClosed = false
    @State private var balance: Decimal = 0
    @State private var name = ""
    @State private var notes = ""
    @State private var balanceText = ""
    @State private var isConfirmingClose = false
    @State private var saveID: UUID?

    init(accountID: UUID) {
        self.accountID = accountID
    }

    private var parsedBalance: Decimal? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
                if !isClosed {
                    TextField("Working Balance", text: $balanceText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark") {
                        saveID = UUID()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave || saveID != nil)
                }
                ToolbarItemGroup(placement: .secondaryAction) {
                    if isClosed {
                        Button("Reopen Account", action: reopen)
                        Button("Delete Account", role: .destructive, action: delete)
                    } else {
                        Button("Close Account", role: .destructive, action: requestClose)
                    }
                }
            }
            .alert("Close Account", isPresented: $isConfirmingClose) {
                Button("Adjust Balance & Close") {
                    close()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Before you can close this account, the balance will have to be zeroed out.")
            }
            .task(id: saveID) {
                guard saveID != nil else { return }
                await save()
            }
            .task {
                #if DEBUG
                print("navigation \(Self.self) accountID=\(accountID)")
                #endif
                guard let accountRepository, let transactionRepository else { return }
                guard let account = await accountRepository.find(id: accountID) else {
                    dismiss()
                    return
                }
                name = account.name
                notes = account.notes
                isClosed = account.isClosed
                let current = account.balance(await transactionRepository.find(accountID: accountID))
                balance = current
                balanceText = current.formatted(.number)
            }
        }
    }

    private var canSave: Bool {
        EditAccount.canExecute(name: name)
    }

    private func save() async {
        guard let accountRepository, let transactionRepository else { return }
        guard EditAccount.canExecute(name: name) else { return }
        do {
            try await EditAccount(accounts: accountRepository, transactions: transactionRepository).execute(
                id: accountID,
                name: name,
                notes: notes,
                workingBalance: parsedBalance ?? 0
            )
            dismiss()
        } catch {
            saveID = nil
        }
    }

    private func requestClose() {
        if balance == 0 {
            close()
        } else {
            isConfirmingClose = true
        }
    }

    private func close() {
        guard let accountRepository, let transactionRepository else { return }
        Task {
            try await CloseAccount(accounts: accountRepository, transactions: transactionRepository)
                .execute(id: accountID)
            dismiss()
        }
    }

    private func reopen() {
        guard let accountRepository else { return }
        Task {
            try await ReopenAccount(accounts: accountRepository).execute(id: accountID)
            dismiss()
        }
    }

    private func delete() {
        // TODO: warn about transferring transactions onto another account
        guard let accountRepository else { return }
        Task {
            try await DeleteAccount(accounts: accountRepository).execute(id: accountID)
            dismiss()
        }
    }
}
