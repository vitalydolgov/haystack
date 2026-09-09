import SwiftData
import SwiftUI

struct EditTransactionSheet: View {
    @Environment(\.unitOfWork) private var unitOfWork
    @Environment(\.dismiss) private var dismiss

    let accountID: UUID

    enum Mode {
        case plain(UUID)
        case transfer(UUID)
    }
    let mode: Mode

    @Query private var transactions: [TransactionRecord]
    @Query private var counterparts: [TransactionRecord]
    
    @State private var amountText = ""
    @State private var isOutflow = true
    @State private var date = Date()
    @State private var notes = ""
    @State private var selectedAccountID = UUID()
    @State private var transferAccountID = UUID()

    @State private var saveID: UUID?

    init(accountID: UUID, mode: Mode) {
        self.accountID = accountID
        self.mode = mode
        switch mode {
        case .plain(let transactionID):
            _transactions = Query(
                filter: #Predicate<TransactionRecord> {
                    $0.id == transactionID && $0.deletedAt == nil
                }
            )
            _counterparts = Query(filter: #Predicate<TransactionRecord> { _ in false })
        case .transfer(let transferID):
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
        case .plain: isTransfer
        case .transfer: !isTransfer
        }
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
                guard let transaction = transactions.first else { return }
                amountText = Self.formattedAmount(transaction.amount)
                isOutflow = transaction.amount < 0
                date = Transaction.date(from: transaction.unpackedDate)
                notes = transaction.notes
                selectedAccountID = transaction.accountID
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
        "Edit Transaction"
    }

    private var canSave: Bool {
        switch mode {
        case .plain where isConversion:
            ConvertTransactionToTransfer.canExecute(amount: signedAmount)
        case .plain:
            EditTransaction.canExecute(amount: signedAmount)
        case .transfer where isConversion:
            ConvertTransferToTransaction.canExecute(amount: signedAmount)
        case .transfer:
            true
        }
    }

    private func save() async {
        guard let unitOfWork else { return }
        do {
            switch mode {
            case .plain(let transactionID) where isConversion:
                guard ConvertTransactionToTransfer.canExecute(amount: signedAmount) else { return }
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
                    toAccountID: selectedAccountID
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
            case .transfer:
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
