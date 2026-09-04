import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: AccountType?
    @State private var balanceText = ""

    private var parsedBalance: Decimal? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    private var canSave: Bool {
        AddAccount.canExecute(name: name, type: type, balance: parsedBalance)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Select").tag(AccountType?.none)
                    ForEach(AccountType.allCases, id: \.self) { type in
                        Text(type.title).tag(Optional(type))
                    }
                }
                TextField("Balance", text: $balanceText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard let accountRepository, let transactionRepository, let type, let parsedBalance else { return }
        guard AddAccount.canExecute(name: name, type: type, balance: parsedBalance) else { return }
        Task {
            _ = try await AddAccount(accounts: accountRepository, transactions: transactionRepository).execute(
                name: name,
                type: type,
                balance: parsedBalance
            )
            dismiss()
        }
    }
}
