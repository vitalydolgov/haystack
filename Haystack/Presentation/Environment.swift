import SwiftUI

extension EnvironmentValues {
    @Entry var unitOfWork: any UnitOfWork = required("unitOfWork")
    @Entry var accountRepository: any AccountQuerying = required("accountRepository")
    @Entry var transactionRepository: any TransactionQuerying = required("transactionRepository")
}

private func required<T>(_ name: String) -> T {
    fatalError("missing environment value \(name)")
}
