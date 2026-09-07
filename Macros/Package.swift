// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "TransactionalMacro",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "TransactionalMacro", targets: ["TransactionalMacro"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"700.0.0")
    ],
    targets: [
        .macro(
            name: "TransactionalMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "TransactionalMacro", dependencies: ["TransactionalMacros"])
    ]
)
