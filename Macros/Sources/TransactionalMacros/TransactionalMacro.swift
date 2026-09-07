import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

enum TransactionalMacroError: String, DiagnosticMessage {
    case notAFunction = "@Transactional can only be applied to a function"
    case noBody = "@Transactional requires a function body"
    case notAsyncThrows = "@Transactional requires an 'async throws' function"

    var message: String { rawValue }
    var severity: DiagnosticSeverity { .error }
    var diagnosticID: MessageID { MessageID(domain: "TransactionalMacros", id: rawValue) }
}

public struct TransactionalMacro: BodyMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
        in context: some MacroExpansionContext
    ) throws -> [CodeBlockItemSyntax] {
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: node, message: TransactionalMacroError.notAFunction)
            ])
        }
        guard let body = function.body else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: node, message: TransactionalMacroError.noBody)
            ])
        }
        let effects = function.signature.effectSpecifiers
        guard effects?.asyncSpecifier != nil, effects?.throwsClause != nil else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: node, message: TransactionalMacroError.notAsyncThrows)
            ])
        }

        let returnType = function.signature.returnClause?.type.trimmed ?? TypeSyntax("Void")
        let statements = body.statements.trimmed

        return [
            """
            return try await unitOfWork.perform { (store: Store) -> \(returnType) in
                \(statements)
            }
            """
        ]
    }
}

@main
struct TransactionalPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [TransactionalMacro.self]
}
