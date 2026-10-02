import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    @State private var amountText = ""
    @State private var kind: TransactionKind = .expense
    @State private var date = Date()
    @State private var notes = ""
    @State private var selectedAccountID: UUID
    @State private var counterpartAccountID: UUID?
    @State private var splitParts: [SplitDraftPart] = []

    @State private var saveID: UUID?

    init(accountID: UUID) {
        self.accountID = accountID
        _selectedAccountID = State(initialValue: accountID)
    }

    private var amount: Decimal {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let parsed = Decimal(string: trimmed, locale: .current) ?? 0
        return kind.signed(magnitude: abs(parsed))
    }

    var body: some View {
        NavigationStack {
            TransactionForm(
                amountText: $amountText,
                kind: $kind,
                date: $date,
                notes: $notes,
                selectedAccountID: $selectedAccountID,
                counterpartAccountID: $counterpartAccountID,
                splitParts: $splitParts,
            )
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
                print("navigation \(Self.self) accountID=\(accountID)")
                #endif
            }
        }
    }

    private var canSave: Bool {
        if case .split = kind {
            guard let split = try? SplitDraft(
                accountID: selectedAccountID,
                date: date,
                amount: amount,
                notes: notes,
                parts: splitParts
            ) else {
                return false
            }
            return AddSplit.canExecute(split.total, parts: split.parts)
        }

        if case .transfer = kind {
            guard let counterpartAccountID else {
                return false
            }
            return AddTransfer.canExecute(
                fromAccountID: selectedAccountID,
                toAccountID: counterpartAccountID,
                magnitude: abs(amount)
            )
        }

        return AddTransaction.canExecute(amount: amount)
    }

    private func save() async {
        do {
            if case .split = kind {
                let split = try? SplitDraft(
                    accountID: selectedAccountID,
                    date: date,
                    amount: amount,
                    notes: notes,
                    parts: splitParts
                )
                guard let split, AddSplit.canExecute(split.total, parts: split.parts) else { return }
                _ = try await AddSplit(unitOfWork: unitOfWork).execute(split.total, parts: split.parts)
            } else if case .transfer = kind, let counterpartAccountID {
                guard AddTransfer.canExecute(
                    fromAccountID: selectedAccountID,
                    toAccountID: counterpartAccountID,
                    magnitude: abs(amount)
                ) else { return }
                _ = try await AddTransfer(unitOfWork: unitOfWork).execute(
                    fromAccountID: selectedAccountID,
                    toAccountID: counterpartAccountID,
                    date: date,
                    magnitude: abs(amount),
                    notes: notes
                )
            } else {
                guard AddTransaction.canExecute(amount: amount) else { return }
                _ = try await AddTransaction(unitOfWork: unitOfWork).execute(
                    accountID: selectedAccountID,
                    date: date,
                    amount: amount,
                    notes: notes
                )
            }
            dismiss()
        } catch {
            saveID = nil
        }
    }
}
