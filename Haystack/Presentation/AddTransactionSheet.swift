import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID
    @State private var amountText = ""
    @State private var isOutflow = true
    @State private var date = Date()
    @State private var notes = ""
    @State private var saveID: UUID?
    @State private var accountName = ""
    @State private var selectedAccountID: UUID

    init(accountID: UUID) {
        self.accountID = accountID
        _selectedAccountID = State(initialValue: accountID)
    }

    private var parsedAmount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    private var signedAmount: Decimal {
        let amount = abs(parsedAmount ?? 0)
        return isOutflow ? -amount : amount
    }

    var body: some View {
        NavigationStack {
            Form {
                // TODO: labels for each field
                // TODO: only positive
                // TODO: never empty
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                Picker("Direction", selection: $isOutflow) {
                    Text("Outflow").tag(true)
                    Text("Inflow").tag(false)
                }
                .pickerStyle(.segmented)
                // TODO: payee
                NavigationLink {
                    // TODO: show as sheet
                    AccountPicker(selectedID: $selectedAccountID)
                } label: {
                    Text(accountName.isEmpty ? "Account" : accountName)
                }
                DatePicker("Date", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                // TODO: allow scheduling in the future
                Section {
                    // TODO: memo
                }
            }
            .navigationTitle("Add Transaction")
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
            .task(id: selectedAccountID) {
                guard let accountRepository else { return }
                if let account = await accountRepository.find(id: selectedAccountID) {
                    accountName = account.name
                }
            }
        }
    }

    private var canSave: Bool {
        AddTransaction.canExecute(accountID: selectedAccountID, amount: signedAmount, date: date)
    }

    private func save() async {
        guard let accountRepository, let transactionRepository else { return }
        guard AddTransaction.canExecute(accountID: selectedAccountID, amount: signedAmount, date: date) else { return }
        do {
            let addTransaction = AddTransaction(accounts: accountRepository, transactions: transactionRepository)
            _ = try await addTransaction.execute(
                accountID: selectedAccountID,
                date: date,
                amount: signedAmount,
                notes: notes
            )
            dismiss()
        } catch {
            saveID = nil
        }
    }
}
