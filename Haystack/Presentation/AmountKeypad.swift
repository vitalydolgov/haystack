import SwiftUI

struct AmountKeypad: View {
    var onDigit: (Int) -> Void
    var onDelete: () -> Void

    // MARK: Views

    private func digitKey(_ digit: Int) -> some View {
        Button {
            onDigit(digit)
        } label: {
            Text("\(digit)")
                .font(.title2)
        }
        .buttonStyle(KeyStyle())
    }

    private var deleteKey: some View {
        Button(action: onDelete) {
            Image(systemName: "delete.left")
                .font(.title3)
        }
        .buttonStyle(KeyStyle())
    }

    var body: some View {
        // TODO: accessibility
        VStack(spacing: 8) {
            ForEach([[7, 8, 9], [4, 5, 6], [1, 2, 3]], id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { digit in
                        digitKey(digit)
                    }
                }
            }
            HStack(spacing: 8) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: KeyStyle.height)
                digitKey(0)
                deleteKey
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) { Divider() }
        }
    }
}

private struct KeyStyle: ButtonStyle {
    static let height: CGFloat = 48

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .contentShape(Rectangle())
            .background(
                configuration.isPressed ? Color(.tertiarySystemFill) : Color(.secondarySystemFill),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}
