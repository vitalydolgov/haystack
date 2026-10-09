import SwiftUI

struct SplitDraft {
    let total: Transaction
    let parts: [Transaction]

    init(
        accountID: UUID,
        date: Date,
        amount: Decimal,
        notes: String,
        parts: [SplitDraftPart]
    ) throws {
        let day = date.asYearMonthDay()
        total = try Transaction(
            accountID: accountID,
            date: day,
            amount: amount,
            notes: notes
        )
        var transactions: [Transaction] = []
        for part in parts where part.amountInCents != 0 {
            let transaction = try Transaction(
                id: part.id,
                accountID: accountID,
                date: day,
                amount: part.kind.signed(magnitude: Decimal(part.amountInCents) / 100),
                notes: ""
            )
            transactions.append(transaction)
        }
        self.parts = transactions
    }
}

struct SplitDraftPart: Identifiable, Equatable {
    let id: UUID
    var kind: TransactionKind
    var amountInCents = 0

    static func from(_ transaction: Transaction) -> SplitDraftPart {
        SplitDraftPart(
            id: transaction.id,
            kind: TransactionKind(of: transaction),
            amountInCents: AmountFormatter.amountInCents(from: transaction.amount)
        )
    }
}

struct SplitDraftEditor: View {
    var kind: TransactionKind
    var amountInCents: Int
    @Binding var parts: [SplitDraftPart]

    @State private var selectedPartID: UUID?

    init(kind: TransactionKind, amountInCents: Int, parts: Binding<[SplitDraftPart]>) {
        self.kind = kind
        self.amountInCents = amountInCents
        _parts = parts
        _selectedPartID = State(initialValue: parts.wrappedValue.first?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach($parts) { $part in
                        PartRow(part: part, selectedPartID: $selectedPartID)
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deletePart(id: part.id)
                                }
                            }
                            .contextMenu {
                                ToggleFlowButton(kind: $part.kind)
                            }
                    }
                    // TODO: transfer
                } header: {
                    SplitHeader(kind: kind, amountInCents: amountInCents, parts: parts)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            AmountKeypad(
                onDigit: pushDigit,
                onDelete: backspace
            )
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Split Transaction")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add", systemImage: "plus") {
                    let part = SplitDraftPart(id: UUID(), kind: kind)
                    parts.append(part)
                    selectedPartID = part.id
                }
            }
        }
    }

    // MARK: Helpers

    private func deletePart(id: UUID) {
        guard let index = parts.firstIndex(where: { $0.id == id }) else { return }
        parts.remove(at: index)
        guard selectedPartID == id else { return }
        selectedPartID = index < parts.count ? parts[index].id : parts.last?.id
    }

    private func pushDigit(_ digit: Int) {
        guard let index = selectedIndex else { return }
        let amountInCents = parts[index].amountInCents
        guard amountInCents <= Self.maximumCents / 10 else { return }
        let next = amountInCents * 10 + digit
        guard next <= Self.maximumCents else { return }
        parts[index].amountInCents = next
    }

    private func backspace() {
        guard let index = selectedIndex else { return }
        parts[index].amountInCents /= 10
    }

    private var selectedIndex: Int? {
        guard let selectedPartID else { return nil }
        return parts.firstIndex { $0.id == selectedPartID }
    }

    private static let maximumCents = 99_999_999
}

private struct ToggleFlowButton: View {
    @Binding var kind: TransactionKind

    var body: some View {
        Button(title, systemImage: symbol) {
            kind = kind == .expense ? .income : .expense
        }
    }

    // MARK: Helpers

    private var title: String {
        kind == .expense ? "Toggle to Inflow" : "Toggle to Outflow"
    }

    private var symbol: String {
        kind == .expense ? "plus" : "minus"
    }
}

private struct PartRow: View {
    var part: SplitDraftPart
    @Binding var selectedPartID: UUID?

    var body: some View {
        Button {
            selectedPartID = part.id
        } label: {
            HStack {
                // TODO: category or transfer
                Spacer()
                Text(AmountFormatter.signedText(from: part.amountInCents, isNegative: part.kind == .expense))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(part.amountInCents == 0 ? .secondary : .primary)
                    .frame(minWidth: 72, alignment: .trailing)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(part.id == selectedPartID ? DeosaiTheme.sky : Color.clear, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SplitHeader: View {
    var kind: TransactionKind
    var amountInCents: Int
    var parts: [SplitDraftPart]

    var body: some View {
        VStack(spacing: 2) {
            HStack {
                // TODO: payee
                Spacer()
                // TODO: hide + sign
                Text(AmountFormatter.signedText(from: amountInCents, isNegative: kind == .expense))
            }
            .font(.headline.monospacedDigit())
            HStack {
                Text("Amount remaining to assign")
                Spacer()
                Text(remainingText)
            }
            .font(.body.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .textCase(nil)
        .padding(.trailing, 8)
    }

    // MARK: Helpers

    private var remainingText: String {
        AmountFormatter.signedText(from: abs(remainingCents), isNegative: remainingCents < 0)
    }

    private var remainingCents: Int {
        let parent = signedCents(kind: kind, amountInCents: amountInCents)
        let allocated = parts.reduce(0) { sum, part in
            sum + signedCents(kind: part.kind, amountInCents: part.amountInCents)
        }
        return parent - allocated
    }

    private func signedCents(kind: TransactionKind, amountInCents: Int) -> Int {
        kind == .expense ? -amountInCents : amountInCents
    }
}

