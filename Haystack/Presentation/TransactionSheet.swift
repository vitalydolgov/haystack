import SwiftData
import SwiftUI

struct TransactionSheet: View {
    enum Mode {
        case add
        case edit(UUID)
        // TODO: edit transfer
    }

    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID
    let mode: Mode
    @Query private var accounts: [AccountRecord]
    @Query private var transactions: [TransactionRecord]
    @State private var amountText = ""
    @State private var isOutflow = true
    @State private var date = Date()
    @State private var notes = ""
    @State private var saveID: UUID?
    @State private var selectedAccountID: UUID
    @State private var transferAccountID: UUID

    init(accountID: UUID, mode: Mode) {
        self.accountID = accountID
        self.mode = mode
        let transactionID = switch mode {
        case .add: UUID()
        case .edit(let id): id
        }
        _selectedAccountID = State(initialValue: accountID)
        _transferAccountID = State(initialValue: accountID)
        _accounts = Query(filter: #Predicate<AccountRecord> { $0.deletedAt == nil })
        _transactions = Query(
            filter: #Predicate<TransactionRecord> {
                $0.id == transactionID && $0.deletedAt == nil
            }
        )
    }

    private var parsedAmount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    private var isMove: Bool {
        selectedAccountID != accountID
    }

    private var isTransfer: Bool {
        selectedAccountID != transferAccountID
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
                // TODO: payee
                NavigationLink {
                    // TODO: show as sheet
                    AccountPicker(selectedID: $selectedAccountID)
                } label: {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(accounts.first { $0.id == selectedAccountID }?.name ?? "None")
                            .foregroundColor(.secondary)
                    }
                }
                NavigationLink {
                    AccountPicker(selectedID: $transferAccountID)
                } label: {
                    HStack {
                        Text("Transfer")
                        Spacer()
                        Group {
                            if isTransfer, let transferAccount = accounts.first(where: { $0.id == transferAccountID }) {
                                Text("\(isOutflow ? "To" : "From"): \(transferAccount.name)")
                            } else {
                                Text("None")
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                DatePicker("Date", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                // TODO: allow scheduling in the future
                Section {
                    // TODO: memo
                }
            }
            .onChange(of: selectedAccountID) { oldValue, newValue in
                if transferAccountID == oldValue {
                    transferAccountID = newValue
                } else if newValue == transferAccountID {
                    transferAccountID = oldValue
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
            .task {
                #if DEBUG
                switch mode {
                case .add:
                    print("navigation \(Self.self) accountID=\(accountID)")
                case .edit(let transactionID):
                    print("navigation \(Self.self) accountID=\(accountID) transactionID=\(transactionID)")
                }
                #endif
                guard case .edit = mode, let transaction = transactions.first else { return }
                let formatter = NumberFormatter()
                formatter.locale = .current
                formatter.numberStyle = .decimal
                amountText = formatter.string(from: NSDecimalNumber(decimal: abs(transaction.amount))) ?? ""
                isOutflow = transaction.amount < 0
                date = Transaction.date(from: transaction.unpackedDate)
                notes = transaction.notes
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
        guard let unitOfWork else { return }
        do {
            switch mode {
            case .add where isTransfer:
                let addTransfer = AddTransfer(unitOfWork: unitOfWork)
                _ = try await addTransfer.execute(
                    fromAccountID: isOutflow ? selectedAccountID : transferAccountID,
                    toAccountID: isOutflow ? transferAccountID : selectedAccountID,
                    date: date,
                    amount: abs(signedAmount),
                    notes: notes
                )
            case .add:
                guard AddTransaction.canExecute(amount: signedAmount) else { return }
                let addTransaction = AddTransaction(unitOfWork: unitOfWork)
                _ = try await addTransaction.execute(
                    accountID: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .edit(let transactionID) where isMove:
                guard MoveTransaction.canExecute(fromAccountID: accountID, toAccountID: selectedAccountID) else { return }
                let moveTransaction = MoveTransaction(unitOfWork: unitOfWork)
                try await moveTransaction.execute(
                    id: transactionID,
                    toAccountID: selectedAccountID
                )
            case .edit(let transactionID):
                guard EditTransaction.canExecute(amount: signedAmount) else { return }
                let editTransaction = EditTransaction(unitOfWork: unitOfWork)
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
