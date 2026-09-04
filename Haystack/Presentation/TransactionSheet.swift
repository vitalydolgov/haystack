import SwiftUI

struct TransactionSheet: View {
    enum Mode {
        case add
        case edit(UUID)
    }

    @Environment(\.accountRepository) private var accountRepository
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID
    let mode: Mode
    @State private var amountText = ""
    @State private var isOutflow = true
    @State private var date = Date()
    @State private var notes = ""
    @State private var saveID: UUID?
    @State private var accountName = ""
    @State private var selectedAccountID: UUID

    init(accountID: UUID, mode: Mode) {
        self.accountID = accountID
        self.mode = mode
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
            .navigationTitle(title)
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
            .task {
                guard case .edit(let transactionID) = mode else { return }
                guard let transactionRepository else { return }
                if let transaction = await transactionRepository.find(id: transactionID) {
                    let formatter = NumberFormatter()
                    formatter.locale = .current
                    formatter.numberStyle = .decimal
                    amountText = formatter.string(from: NSDecimalNumber(decimal: abs(transaction.amount))) ?? ""
                    isOutflow = transaction.amount < 0
                    date = Transaction.date(from: transaction.date)
                    notes = transaction.notes
//                    selectedAccountID = transaction.accountID
                }
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: "Add Transaction"
        case .edit: "Edit Transaction"
        }
    }

    private var canSave: Bool {
        switch mode {
        case .add:
            AddTransaction.canExecute(amount: signedAmount)
        case .edit:
            EditTransaction.canExecute(amount: signedAmount)
        }
    }

    private func save() async {
        guard let accountRepository, let transactionRepository else { return }
        do {
            switch mode {
            case .add:
                guard AddTransaction.canExecute(amount: signedAmount) else { return }
                let addTransaction = AddTransaction(accounts: accountRepository, transactions: transactionRepository)
                _ = try await addTransaction.execute(
                    accountID: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .edit(let transactionID) where selectedAccountID != accountID:
                guard MoveTransaction.canExecute(fromAccountID: accountID, toAccountID: selectedAccountID) else { return }
                let moveTransaction = MoveTransaction(accounts: accountRepository, transactions: transactionRepository)
                try await moveTransaction.execute(
                    id: transactionID,
                    toAccountID: selectedAccountID
                )
            case .edit(let transactionID):
                guard EditTransaction.canExecute(amount: signedAmount) else { return }
                let editTransaction = EditTransaction(accounts: accountRepository, transactions: transactionRepository)
                try await editTransaction.execute(
                    id: transactionID,
                    accountID: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            }
            dismiss()
        } catch {
            saveID = nil
        }
    }
}
