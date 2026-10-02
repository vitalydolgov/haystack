import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.transactionRepository) private var transactionRepository
    @Environment(\.dismiss) private var dismiss

    let transactionID: UUID
    let transferID: UUID?

    @State private var amountText = ""
    @State private var transactionKind: TransactionKind = .expense
    @State private var date = Date()
    @State private var notes = ""
    @State private var selectedAccountID = UUID()
    @State private var counterpartAccountID: UUID?
    @State private var splitParts: [SplitDraftPart] = []

    @State private var initialSelectedAccountID = UUID()
    @State private var initialCounterpartAccountID: UUID?

    @State private var saveID: UUID?

    private var amount: Decimal {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let parsed = Decimal(string: trimmed, locale: .current) ?? 0
        return transactionKind.signed(magnitude: abs(parsed))
    }

    var body: some View {
        NavigationStack {
            TransactionForm(
                amountText: $amountText,
                kind: $transactionKind,
                date: $date,
                notes: $notes,
                selectedAccountID: $selectedAccountID,
                counterpartAccountID: $counterpartAccountID,
                splitParts: $splitParts,
            )
            .navigationTitle("Edit Transaction")
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
                    .tint(DeosaiTheme.sky)
                    .disabled(!canSave || saveID != nil)
                }
            }
            .task(id: saveID) {
                guard saveID != nil else { return }
                await save()
            }
            .task {
                #if DEBUG
                print("navigation \(Self.self) transactionID=\(transactionID)")
                #endif
                await prefill()
            }
        }
    }

    private func prefill() async {
        guard let transaction = await transaction(id: transactionID) else { return }
        transactionKind = TransactionKind(of: transaction)
        if transferID != nil {
            guard let counterpart = await counterpart(transactionID: transactionID) else { return }
            amountText = AmountFormatter.text(from: transaction.amount)
            date = Transaction.date(from: transaction.date)
            notes = transaction.notes
            if transaction.amount < 0 {
                selectedAccountID = transaction.accountID
                counterpartAccountID = counterpart.accountID
            } else {
                selectedAccountID = counterpart.accountID
                counterpartAccountID = transaction.accountID
            }
            initialSelectedAccountID = selectedAccountID
            initialCounterpartAccountID = counterpartAccountID
        } else {
            amountText = AmountFormatter.text(from: transaction.amount)
            date = Transaction.date(from: transaction.date)
            notes = transaction.notes
            selectedAccountID = transaction.accountID
            counterpartAccountID = nil
            initialSelectedAccountID = selectedAccountID
            initialCounterpartAccountID = nil
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

    private func counterpart(transactionID: UUID) async -> Transaction? {
        do {
            return try await transactionRepository.queryCounterpart(transactionID: transactionID)
        } catch {
            print("error: \(error)")
            return nil
        }
    }

    private var isConversion: Bool {
        transferID == nil && transactionKind.isTransfer || transferID != nil && transactionKind.isPlain
    }

    private var isMove: Bool {
        if transferID == nil {
            selectedAccountID != initialSelectedAccountID
        } else {
            selectedAccountID != initialSelectedAccountID || counterpartAccountID != initialCounterpartAccountID
        }
    }

    private var canSave: Bool {
        // TODO: handle split
        if transactionKind.isPlain {
            canSavePlain
        } else {
            canSaveTransfer
        }
    }

    private var canSavePlain: Bool {
        if isConversion {
            ConvertTransferToTransaction.canExecute(amount: amount)
        } else if isMove {
            MoveTransaction.canExecute(fromAccountID: initialSelectedAccountID, toAccountID: selectedAccountID)
        } else {
            EditTransaction.canExecute(amount: amount)
        }
    }

    private var canSaveTransfer: Bool {
        if isConversion {
            guard let counterpartAccountID else {
                return false
            }
            return ConvertTransactionToTransfer.canExecute(
                accountID: selectedAccountID,
                counterpartAccountID: counterpartAccountID,
                amount: amount
            )
        } else if isMove {
            guard let counterpartAccountID else {
                return false
            }
            return ReplaceTransfer.canExecute(
                fromAccountID: selectedAccountID,
                toAccountID: counterpartAccountID,
                amount: abs(amount)
            )
        } else {
            return EditTransfer.canExecute(amount: amount)
        }
    }

    private func save() async {
        do {
            // TODO: handle split
            if transactionKind.isPlain {
                try await savePlain()
            } else {
                try await saveTransfer()
            }
            dismiss()
        } catch {
            saveID = nil
        }
    }

    private func savePlain() async throws {
        if isConversion {
            guard let transferID,
                  let transaction = await transaction(id: transactionID) else {
                throw PresentationError.cannotExecute
            }
            try await ConvertTransferToTransaction(unitOfWork: unitOfWork).execute(
                transferID: transferID,
                keeping: transaction.accountID,
                movingTo: selectedAccountID,
                date: date,
                amount: amount,
                notes: notes
            )
        } else if isMove {
            try await MoveTransaction(unitOfWork: unitOfWork).execute(
                id: transactionID,
                movingTo: selectedAccountID
            )
        } else {
            try await EditTransaction(unitOfWork: unitOfWork).execute(
                id: transactionID,
                accountID: selectedAccountID,
                date: date,
                amount: amount,
                notes: notes
            )
        }
    }

    private func saveTransfer() async throws {
        if isConversion {
            guard let counterpartAccountID else {
                throw PresentationError.cannotExecute
            }
            try await ConvertTransactionToTransfer(unitOfWork: unitOfWork).execute(
                id: transactionID,
                accountID: selectedAccountID,
                counterpartAccountID: counterpartAccountID,
                date: date,
                amount: amount,
                notes: notes
            )
        } else if isMove {
            guard let transferID, let counterpartAccountID else {
                throw PresentationError.cannotExecute
            }
            try await ReplaceTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                fromAccountID: selectedAccountID,
                toAccountID: counterpartAccountID,
                date: date,
                amount: abs(amount),
                notes: notes
            )
        } else {
            guard let transferID else {
                throw PresentationError.cannotExecute
            }
            try await EditTransfer(unitOfWork: unitOfWork).execute(
                id: transferID,
                accountID: selectedAccountID,
                date: date,
                amount: amount,
                notes: notes
            )
        }
    }
}
