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
    @State private var transferAccountID: UUID

    @State private var saveID: UUID?

    init(accountID: UUID) {
        self.accountID = accountID
        _selectedAccountID = State(initialValue: accountID)
        _transferAccountID = State(initialValue: accountID)
    }

    private var parsedAmount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed, locale: .current)
    }

    private var isTransfer: Bool {
        kind == .transfer
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
            .task {
                #if DEBUG
                print("navigation \(Self.self) accountID=\(accountID)")
                #endif
            }
        }
    }

    private var canSave: Bool {
        if isTransfer {
            AddTransfer.canExecute(
                fromAccountID: selectedAccountID,
                toAccountID: transferAccountID,
                amount: abs(signedAmount)
            )
        } else {
            AddTransaction.canExecute(amount: signedAmount)
        }
    }

    private func save() async {
        do {
            if isTransfer {
                guard AddTransfer.canExecute(
                    fromAccountID: selectedAccountID,
                    toAccountID: transferAccountID,
                    amount: abs(signedAmount)
                ) else { return }
                _ = try await AddTransfer(unitOfWork: unitOfWork).execute(
                    fromAccountID: selectedAccountID,
                    toAccountID: transferAccountID,
                    date: date,
                    amount: abs(signedAmount),
                    notes: notes
                )
            } else {
                guard AddTransaction.canExecute(amount: signedAmount) else { return }
                _ = try await AddTransaction(unitOfWork: unitOfWork).execute(
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
