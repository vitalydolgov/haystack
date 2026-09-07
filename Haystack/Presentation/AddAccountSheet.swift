import SwiftUI

struct AddAccountSheet: View {
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type: AccountType?
    @State private var balanceText = ""
    @State private var saveID: UUID?

    private var parsedBalance: Decimal? {
        let trimmed = balanceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
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
                    Button("Save", systemImage: "checkmark") {
                        saveID = UUID()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(!canSave || saveID != nil)
                }
            }
            .task(id: saveID) {
                guard saveID != nil else { return }
                await save()
            }
        }
    }

    private var canSave: Bool {
        guard type != nil, parsedBalance != nil else { return false }
        return AddAccount.canExecute(name: name)
    }

    private func save() async {
        guard let accountRepository, let transactionRepository, let type else { return }
        let balance = parsedBalance ?? 0
        guard AddAccount.canExecute(name: name) else { return }
        do {
            let addAccount = AddAccount(accounts: accountRepository, transactions: transactionRepository)
            _ = try await addAccount.execute(
                name: name,
                type: type,
                balance: balance
            )
            dismiss()
        } catch {
            saveID = nil
        }
    }
}
