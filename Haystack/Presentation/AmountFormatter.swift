import Foundation

struct AmountFormatter {
    static func currency(amountInCents: Int) -> String {
        decimal(from: amountInCents).formatted(
            .currency(code: currencyCode).locale(.current)
        )
    }

    static func text(from amountInCents: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: decimal(from: amountInCents) as NSDecimalNumber) ?? ""
    }

    static func text(from amount: Decimal) -> String {
        text(from: amountInCents(from: amount))
    }

    static func amountInCents(from text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: trimmed) else { return 0 }
        return amountInCents(from: number.decimalValue)
    }

    static func amountInCents(from amount: Decimal) -> Int {
        var scaled = abs(amount) * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    private static func decimal(from amountInCents: Int) -> Decimal {
        Decimal(amountInCents) / 100
    }
}
