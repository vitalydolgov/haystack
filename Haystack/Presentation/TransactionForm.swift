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

    var isTransfer: Bool {
        self == .transfer
    }

    var isPlain: Bool {
        !isTransfer
    }

    init(of transaction: Transaction) {
        if transaction.type.transferID != nil {
            self = .transfer
        } else if transaction.amount < 0 {
            self = .expense
        } else {
            self = .income
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

    @State private var picker: PickerField?
    @State private var accounts: [Account] = []
    @State private var amountInCents: Int = 0

    @Environment(\.accountRepository) private var accountRepository

    // MARK: Views

    private var accountRow: some View {
        Button {
            picker = .account
        } label: {
            HStack {
                let title = switch kind {
                case .expense, .income:
                    "Account"
                case .transfer:
                    "Transfer From"
                }
                Text(title)
                Spacer()
                Text(name(of: selectedAccount()))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var transferRow: some View {
        Button {
            picker = .transfer
        } label: {
            HStack {
                Text("Transfer To")
                Spacer()
                Text(name(of: counterpartAccount()))
                .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

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
                    accountRow
                    if kind.isTransfer {
                        transferRow
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
            switch newValue {
            case .expense, .income:
                counterpartAccountID = nil
            case .transfer:
                if counterpartAccountID == selectedAccountID {
                    counterpartAccountID = nil
                }
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

private struct KindPicker: View {
    @Binding var kind: TransactionKind

    // MARK: Views

    private func chip(_ value: TransactionKind, title: String) -> some View {
        let isSelected = kind == value
        return Button {
            kind = value
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    var body: some View {
        HStack(spacing: 8) {
            chip(.expense, title: "Expense")
            chip(.income, title: "Income")
            chip(.transfer, title: "Transfer")
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
        let formatted = AmountFormatter.currency(amountInCents: amountInCents)
        guard let sign else { return formatted }
        return sign + formatted
    }

    private var sign: String? {
        guard amountInCents > 0 else { return nil }
        switch kind {
        case .expense:
            return "−"
        case .income:
            return "+"
        case .transfer:
            return nil
        }
    }

    private var amountContext: String {
        switch kind {
        case .expense:
            "From \(name(of: selectedAccount))"
        case .income:
            "Into \(name(of: selectedAccount))"
        case .transfer:
            "\(name(of: selectedAccount)) → \(name(of: counterpartAccount))"
        }
    }
}

private func name(of account: Account?) -> String {
    account?.name ?? "None"
}
