import SwiftUI

struct EditAccountSheet: View {
    private let accountID: UUID
    @State private var isClosed = false
    @State private var balance: Decimal = 0
    @State private var name = ""
    @State private var notes = ""
    @State private var balanceText = ""
    @State private var isConfirmingClose = false
    @State private var saveID: UUID?

    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

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
                guard let account = await account() else {
                    dismiss()
                    return
                }
                name = account.name
                notes = account.notes
                isClosed = account.isClosed
                let current = await workingBalance()
                balance = current
                balanceText = current.formatted(.number)
            }
        }
    }

    private func account() async -> Account? {
        do {
            return try await accountRepository.query(id: accountID)
        } catch {
            print("error: \(error)")
            return nil
        }
    }

    private func workingBalance() async -> Decimal {
        do {
            let transactions = try await transactionRepository.query(.account(accountID))
            return transactions.reduce(into: 0 as Decimal) { total, transaction in
                total += transaction.amount
            }
        } catch {
            print("error: \(error)")
            return 0
        }
    }

    private var canSave: Bool {
        EditAccount.canExecute(name: name)
    }

    private func save() async {
        guard EditAccount.canExecute(name: name) else { return }
        do {
            try await EditAccount(unitOfWork: unitOfWork).execute(
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
        Task {
            try await CloseAccount(unitOfWork: unitOfWork).execute(id: accountID)
            dismiss()
        }
    }

    private func reopen() {
        Task {
            try await ReopenAccount(unitOfWork: unitOfWork).execute(id: accountID)
            dismiss()
        }
    }

    private func delete() {
        // TODO: warn about transferring transactions onto another account
        Task {
            try await DeleteAccount(unitOfWork: unitOfWork).execute(id: accountID)
            dismiss()
        }
    }
}
