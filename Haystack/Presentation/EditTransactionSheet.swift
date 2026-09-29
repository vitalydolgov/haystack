import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    enum Mode {
        case plain(UUID)
        case transfer(UUID)
    }
    let mode: Mode

    @State private var amountText = ""
    @State private var kind: TransactionKind = .expense
    @State private var date = Date()
    @State private var notes = ""
    @State private var selectedAccountID = UUID()
    @State private var transferAccountID = UUID()
    @State private var loadedSelectedAccountID = UUID()
    @State private var loadedTransferAccountID = UUID()

    @State private var saveID: UUID?

    private var parsedAmount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    private var isMove: Bool {
        switch mode {
        case .plain:
            selectedAccountID != accountID
        case .transfer:
            selectedAccountID != loadedSelectedAccountID || transferAccountID != loadedTransferAccountID
        }
    }

    private var isTransfer: Bool {
        kind == .transfer
    }

    private var isConversion: Bool {
        switch mode {
        case .plain: isTransfer
        case .transfer: !isTransfer
        }
    }

    private var signedAmount: Decimal {
        let amount = abs(parsedAmount ?? 0)
        switch kind {
        case .income:
            return amount
        case .expense, .transfer:
            return -amount
        }
    }

    var body: some View {
        NavigationStack {
            TransactionForm(
                amountText: $amountText,
                kind: $kind,
                date: $date,
                notes: $notes,
                selectedAccountID: $selectedAccountID,
                transferAccountID: $transferAccountID,
            )
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
                case .plain(let transactionID):
                    print("navigation \(Self.self) accountID=\(accountID) transactionID=\(transactionID)")
                case .transfer(let transferID):
                    print("navigation \(Self.self) accountID=\(accountID) transferID=\(transferID)")
                }
                #endif
                switch mode {
                case .plain(let transactionID):
                    guard let transaction = await transaction(id: transactionID) else { return }
                    show(transaction)
                case .transfer(let transferID):
                    guard let (outflow, inflow) = await transfer(id: transferID) else { return }
                    let transaction = outflow.accountID == accountID ? outflow : inflow
                    let counterpart = outflow.accountID == accountID ? inflow : outflow
                    show(transaction, counterpartAccountID: counterpart.accountID)
                }
            }
        }
    }

    private func transaction(id: UUID) async -> Transaction? {
        do {
            return try await transactionRepository.query(id: id)
        } catch {
            print("error: \(error)")
            return nil
        }
    }

    private func transfer(id: UUID) async -> (Transaction, Transaction)? {
        do {
            return try await transactionRepository.queryTransfer(id: id)
        } catch {
            print("error: \(error)")
            return nil
        }
    }

    private func show(_ transaction: Transaction, counterpartAccountID: UUID? = nil) {
        amountText = AmountFormatter.text(from: transaction.amount)
        date = Transaction.date(from: transaction.date)
        notes = transaction.notes
        if let counterpartAccountID {
            kind = .transfer
            if transaction.amount < 0 {
                selectedAccountID = transaction.accountID
                transferAccountID = counterpartAccountID
            } else {
                selectedAccountID = counterpartAccountID
                transferAccountID = transaction.accountID
            }
        } else {
            kind = transaction.amount < 0 ? .expense : .income
            selectedAccountID = transaction.accountID
            transferAccountID = transaction.accountID
        }
        loadedSelectedAccountID = selectedAccountID
        loadedTransferAccountID = transferAccountID
    }

    private var title: String {
        "Edit Transaction"
    }

    private var canSave: Bool {
        switch mode {
        case .plain where isConversion:
            ConvertTransactionToTransfer.canExecute(
                accountID: selectedAccountID,
                counterpartAccountID: transferAccountID,
                amount: signedAmount
            )
        case .plain:
            EditTransaction.canExecute(amount: signedAmount)
        case .transfer where isConversion:
            ConvertTransferToTransaction.canExecute(amount: signedAmount)
        case .transfer where isMove:
            ReplaceTransfer.canExecute(
                fromAccountID: selectedAccountID,
                toAccountID: transferAccountID,
                amount: abs(signedAmount)
            )
        case .transfer:
            EditTransfer.canExecute(amount: signedAmount)
        }
    }

    private func save() async {
        do {
            switch mode {
            case .plain(let transactionID) where isConversion:
                guard ConvertTransactionToTransfer.canExecute(
                    accountID: selectedAccountID,
                    counterpartAccountID: transferAccountID,
                    amount: signedAmount
                ) else { return }
                try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                    id: transactionID,
                    accountID: selectedAccountID,
                    counterpartAccountID: transferAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .plain(let transactionID) where isMove:
                guard MoveTransaction.canExecute(fromAccountID: accountID, toAccountID: selectedAccountID) else { return }
                try await MoveTransaction(unitOfWork: unitOfWork).execute(
                    id: transactionID,
                    movingTo: selectedAccountID
                )
            case .plain(let transactionID):
                guard EditTransaction.canExecute(amount: signedAmount) else { return }
                try await EditTransaction(unitOfWork: unitOfWork).execute(
                    id: transactionID,
                    accountID: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .transfer(let transferID) where isConversion:
                guard ConvertTransferToTransaction.canExecute(amount: signedAmount) else { return }
                try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                    transferID: transferID,
                    keeping: accountID,
                    movingTo: selectedAccountID,
                    date: date,
                    amount: signedAmount,
                    notes: notes
                )
            case .transfer(let transferID) where isMove:
                guard ReplaceTransfer.canExecute(
                    fromAccountID: selectedAccountID,
                    toAccountID: transferAccountID,
                    amount: abs(signedAmount)
                ) else {
                    saveID = nil
                    return
                }
                try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                    id: transferID,
                    fromAccountID: selectedAccountID,
                    toAccountID: transferAccountID,
                    date: date,
                    amount: abs(signedAmount),
                    notes: notes
                )
            case .transfer(let transferID):
                guard EditTransfer.canExecute(amount: signedAmount) else {
                    saveID = nil
                    return
                }
                try await EditTransfer(unitOfWork: unitOfWork).execute(
                    id: transferID,
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
