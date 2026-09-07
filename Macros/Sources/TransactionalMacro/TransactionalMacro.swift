/// Runs the annotated method's body inside a unit of work transaction.
///
/// The body is wrapped in `unitOfWork.perform { store in ... }`, so it can use
/// `store` directly and the enclosing type must hold a `unitOfWork` property.
/// The method must be `async throws`.
@attached(body)
public macro Transactional() =
    #externalMacro(module: "TransactionalMacros", type: "TransactionalMacro")
