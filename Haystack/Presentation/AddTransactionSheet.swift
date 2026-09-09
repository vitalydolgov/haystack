import SwiftData
import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    @State private var amountText = ""
    @State private var isOutflow = true
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
        selectedAccountID != transferAccountID
    }

    private var signedAmount: Decimal {
        let amount = abs(parsedAmount ?? 0)
        return isOutflow ? -amount : amount
    }

    var body: some View {
        NavigationStack {
            TransactionForm(
                amountText: $amountText,
                isOutflow: $isOutflow,
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
        AddTransaction.canExecute(amount: signedAmount)
    }

    private func save() async {
        guard let unitOfWork else { return }
        do {
            if isTransfer {
                _ = try await AddTransfer(unitOfWork: unitOfWork).execute(
                    fromAccountID: isOutflow ? selectedAccountID : transferAccountID,
                    toAccountID: isOutflow ? transferAccountID : selectedAccountID,
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
