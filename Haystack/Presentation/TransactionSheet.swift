import SwiftData
import SwiftUI

struct TransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    enum Mode {
        case add
        case edit(UUID)
        case editTransfer(UUID)
    }
    let mode: Mode

    @Query private var accounts: [AccountRecord]
    @Query private var transactions: [TransactionRecord]
    @Query private var counterparts: [TransactionRecord]
    @State private var amountText = ""
    @State private var isOutflow = true
    @State private var date = Date()
    @State private var notes = ""
    @State private var saveID: UUID?
    @State private var selectedAccountID: UUID
    @State private var transferAccountID: UUID

    enum PickerField: Identifiable {
        case account
        case transfer

        var id: Self { self }
    }
    @State private var picker: PickerField?

    init(accountID: UUID, mode: Mode) {
        self.accountID = accountID
        self.mode = mode
        _selectedAccountID = State(initialValue: accountID)
        _transferAccountID = State(initialValue: accountID)
        _accounts = Query(filter: #Predicate<AccountRecord> { $0.deletedAt == nil })
        switch mode {
        case .add:
            _transactions = Query(filter: #Predicate<TransactionRecord> { _ in false })
            _counterparts = Query(filter: #Predicate<TransactionRecord> { _ in false })
        case .edit(let transactionID):
            _transactions = Query(
                filter: #Predicate<TransactionRecord> {
                    $0.id == transactionID && $0.deletedAt == nil
                }
            )
            _counterparts = Query(filter: #Predicate<TransactionRecord> { _ in false })
        case .editTransfer(let transferID):
            _transactions = Query(
                filter: #Predicate<TransactionRecord> {
                    $0.transferID == transferID && $0.accountID == accountID && $0.deletedAt == nil
                }
            )
            _counterparts = Query(
                filter: #Predicate<TransactionRecord> {
                    $0.transferID == transferID && $0.accountID != accountID && $0.deletedAt == nil
                }
            )
        }
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

    private var isConversion: Bool {
        switch mode {
        case .add: false
        case .edit: isTransfer
        case .editTransfer: !isTransfer
        }
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
                Button {
                    picker = .account
                } label: {
                    HStack {
                        Text("Account")
                        Spacer()
                        Text(accounts.first { $0.id == selectedAccountID }?.name ?? "None")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                // TODO: allow clearing the transfer account (None)
                Button {
                    picker = .transfer
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
                .buttonStyle(.plain)
                DatePicker("Date", selection: $date, in: Date.distantPast...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                // TODO: allow scheduling in the future
                Section {
                    // TODO: memo
                }
            }
            .sheet(item: $picker) { field in
                switch field {
                case .account:
                    AccountPicker(selectedID: $selectedAccountID)
                case .transfer:
                    AccountPicker(selectedID: $transferAccountID)
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
                case .editTransfer(let transferID):
                    print("navigation \(Self.self) accountID=\(accountID) transferID=\(transferID)")
                }
                #endif
                if case .add = mode { return }
                guard let transaction = transactions.first else { return }
                amountText = Self.formattedAmount(transaction.amount)
                isOutflow = transaction.amount < 0
                date = Transaction.date(from: transaction.unpackedDate)
                notes = transaction.notes
                if let counterpart = counterparts.first {
                    transferAccountID = counterpart.accountID
                }
            }
        }
    }

    private static func formattedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        return formatter.string(from: NSDecimalNumber(decimal: abs(amount))) ?? ""
    }

    private var title: String {
        switch mode {
        case .add: "Add Transaction"
        case .edit, .editTransfer: "Edit Transaction"
        }
    }

    private var canSave: Bool {
        switch mode {
        case .add:
            AddTransaction.canExecute(amount: signedAmount)
        case .edit where isConversion:
            ConvertTransactionToTransfer.canExecute(amount: signedAmount)
        case .edit:
            EditTransaction.canExecute(amount: signedAmount)
        case .editTransfer where isConversion:
            ConvertTransferToTransaction.canExecute(amount: signedAmount)
        case .editTransfer:
            true
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
            case .edit(let transactionID) where isConversion:
                guard ConvertTransactionToTransfer.canExecute(amount: signedAmount) else { return }
                let convertTransaction = ConvertTransactionToTransfer(unitOfWork: unitOfWork)
                try await convertTransaction.execute(
                    id: transactionID,
                    accountID: selectedAccountID,
                    counterpartAccountID: transferAccountID,
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
            case .editTransfer(let transferID) where isConversion:
                guard ConvertTransferToTransaction.canExecute(amount: signedAmount) else { return }
                let convertTransfer = ConvertTransferToTransaction(unitOfWork: unitOfWork)
                try await convertTransfer.execute(
                    transferID: transferID,
                    keeping: accountID,
                    movingTo: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .editTransfer:
                // TODO: edit transfer in place
                // TODO: edit transfer with move
                fatalError()
            }
            dismiss()
        } catch {
            saveID = nil
        }
    }
}
