import SwiftUI

private enum PickerField: Identifiable {
    case account
    case transfer

    var id: Self { self }
}

enum TransactionKind: Hashable {
    case expense
    case income
    case transfer
    indirect case split(TransactionKind)

    var isTransfer: Bool {
        self == .transfer
    }

    var isPlain: Bool {
        switch self {
        case .expense, .income:
            true
        case .transfer, .split:
            false
        }
    }

    var isSplit: Bool {
        if case .split = self {
            true
        } else {
            false
        }
    }

    init(of transaction: Transaction) {
        if transaction.type.transferID != nil {
            self = .transfer
        } else if case .split = transaction.type {
            self = .split(transaction.amount < 0 ? .expense : .income)
        } else if transaction.amount < 0 {
            self = .expense
        } else {
            self = .income
        }
    }

    func signed(magnitude: Decimal) -> Decimal {
        switch self {
        case .income:
            magnitude
        case .expense, .transfer:
            -magnitude
        case .split(let direction):
            direction.signed(magnitude: magnitude)
        }
    }
}

struct TransactionForm: View {
    @Binding var amountText: String
    @Binding var kind: TransactionKind
    @Binding var date: Date
    @Binding var notes: String
    @Binding var selectedAccountID: UUID
    @Binding var counterpartAccountID: UUID?
    @Binding var splitParts: [SplitDraftPart]

    @State private var picker: PickerField?
    @State private var accounts: [Account] = []
    @State private var amountInCents: Int = 0

    @Environment(\.accountRepository) private var accountRepository

    var body: some View {
        VStack(spacing: 0) {
            KindPicker(kind: $kind)
            AmountBlock(
                amountInCents: amountInCents,
                selectedAccount: selectedAccount(),
                counterpartAccount: counterpartAccount(),
                kind: kind
            )
            Form {
                // TODO: payee
                Section {
                    // TODO: category
                    if !kind.isTransfer {
                        let direction = if case .split(let direction) = kind { direction } else { kind }
                        SplitButton(kind: direction, amountInCents: amountInCents, parts: $splitParts)
                    }
                    AccountRow(kind: kind, account: selectedAccount(), picker: $picker)
                    if kind.isTransfer {
                        TransferRow(account: counterpartAccount(), picker: $picker)
                    }
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: Date.distantPast...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    // TODO: allow scheduling in the future
                    // TODO: memo
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            AmountKeypad(
                onDigit: pushDigit,
                onDelete: backspace
            )
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $picker) { field in
            switch field {
            case .account:
                AccountPicker(selectedID: $selectedAccountID)
            case .transfer:
                AccountPicker(optionalID: $counterpartAccountID)
            }
        }
        .task {
            accounts = await accounts()
        }
        .onChange(of: kind) { _, newValue in
            // drop the transfer counterpart
            switch newValue {
            case .expense, .income, .split:
                counterpartAccountID = nil
            case .transfer:
                if counterpartAccountID == selectedAccountID {
                    counterpartAccountID = nil
                }
            }

            // update the split for convenience
            let direction: TransactionKind
            switch newValue {
            case .expense, .income: direction = newValue
            case .split(let value): direction = value
            case .transfer: return
            }
            for index in splitParts.indices {
                guard splitParts[index].amountInCents == 0,
                      splitParts[index].kind != direction else {
                    continue
                }
                splitParts[index].kind = direction
            }
        }
        .onChange(of: splitParts) { _, parts in
            let hasSplit = parts.contains { $0.amountInCents != 0 }
            if hasSplit, !kind.isSplit {
                kind = .split(kind)
            } else if !hasSplit, case .split(let direction) = kind {
                kind = direction
            }
        }
        .onChange(of: selectedAccountID) { oldValue, newValue in
            if counterpartAccountID == newValue {
                counterpartAccountID = oldValue
            }
        }
        .onChange(of: counterpartAccountID) { oldValue, newValue in
            if let oldValue, selectedAccountID == newValue {
                selectedAccountID = oldValue
            }
        }
        .onChange(of: amountText, initial: true) { _, newValue in
            let parsed = AmountFormatter.amountInCents(from: newValue)
            if parsed != amountInCents {
                amountInCents = parsed
            }
            let formatted = parsed == 0 ? "" : AmountFormatter.text(from: parsed)
            if newValue != formatted {
                amountText = formatted
            }
        }
    }

    // MARK: Tasks

    private func accounts() async -> [Account] {
        do {
            return try await accountRepository.query(.open)
        } catch {
            print("error: \(error)")
            return []
        }
    }

    // MARK: Helpers

    private func account(with id: UUID) -> Account? {
        accounts.first { $0.id == id }
    }

    private func selectedAccount() -> Account? {
        account(with: selectedAccountID)
    }

    private func counterpartAccount() -> Account? {
        guard let counterpartAccountID else {
            return nil
        }
        return account(with: counterpartAccountID)
    }

    private func pushDigit(_ digit: Int) {
        guard amountInCents <= Self.maximumCents / 10 else { return }
        let next = amountInCents * 10 + digit
        guard next <= Self.maximumCents else { return }
        amountInCents = next
        amountText = AmountFormatter.text(from: next)
    }

    private func backspace() {
        amountInCents /= 10
        amountText = amountInCents == 0 ? "" : AmountFormatter.text(from: amountInCents)
    }

    private static let maximumCents = 99_999_999
}

private struct SplitButton: View {
    var kind: TransactionKind
    var amountInCents: Int
    @Binding var parts: [SplitDraftPart]

    @State private var isEditing = false

    var body: some View {
        Button {
            if parts.isEmpty {
                parts.append(SplitDraftPart(id: UUID(), kind: kind))
            }
            isEditing = true
        } label: {
            Text("Split")
                .font(.footnote)
                .textCase(.uppercase)
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .navigationDestination(isPresented: $isEditing) {
            SplitDraftEditor(kind: kind, amountInCents: amountInCents, parts: $parts)
        }
    }
}

private struct TransferRow: View {
    var account: Account?
    @Binding var picker: PickerField?

    var body: some View {
        Button {
            picker = .transfer
        } label: {
            HStack {
                Text("Transfer To")
                Spacer()
                Text(name(of: account))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AccountRow: View {
    var kind: TransactionKind
    var account: Account?
    @Binding var picker: PickerField?

    var body: some View {
        Button {
            picker = .account
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(name(of: account))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private var title: String {
        switch kind {
        case .expense, .income, .split:
            "Account"
        case .transfer:
            "Transfer From"
        }
    }
}

private struct KindPicker: View {
    @Binding var kind: TransactionKind

    // MARK: Views

    private func chip(_ value: TransactionKind, title: String, isEnabled: Bool = true) -> some View {
        let isSelected = switch kind {
        case .split(let direction):
            direction == value
        case .expense, .income, .transfer:
            kind == value
        }
        return Button {
            if case .split = kind {
                kind = .split(value)
            } else {
                kind = value
            }
        } label: {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? Color.black : Color.primary)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? DeosaiTheme.straw : Color(.systemBackground), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var body: some View {
        HStack(spacing: 8) {
            chip(.expense, title: "Expense")
            chip(.income, title: "Income")
            chip(.transfer, title: "Transfer", isEnabled: !kind.isSplit)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}

private struct AmountBlock: View {
    var amountInCents: Int
    var selectedAccount: Account?
    var counterpartAccount: Account?
    var kind: TransactionKind

    var body: some View {
        VStack(spacing: 6) {
            Text(display)
                .font(.largeTitle)
                .monospacedDigit()
                .foregroundStyle(amountInCents == 0 ? .secondary : .primary)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
            // TODO: accessibility
            Text(amountContext)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: Helpers

    private var display: String {
        switch kind {
        case .expense, .split(.expense):
            AmountFormatter.signedText(from: amountInCents, isNegative: true)
        case .income, .split(.income):
            AmountFormatter.signedText(from: amountInCents, isNegative: false)
        case .transfer, .split:
            AmountFormatter.currency(amountInCents: amountInCents)
        }
    }

    private var amountContext: String {
        switch kind {
        case .expense, .split(.expense):
            "From \(name(of: selectedAccount))"
        case .income, .split(.income):
            "Into \(name(of: selectedAccount))"
        case .transfer:
            "\(name(of: selectedAccount)) → \(name(of: counterpartAccount))"
        case .split:
            "From \(name(of: selectedAccount))"
        }
    }
}

private func name(of account: Account?) -> String {
    account?.name ?? "None"
}
