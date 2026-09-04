// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "ObservableViewModel",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ObservableViewModel",
            targets: ["ObservableViewModel"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", .upToNextMajor(from: "3.3.2")),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0" ..< "603.0.0"),
    ],
    targets: [
        .macro(
            name: "ObservableViewModelMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "ObservableViewModel",
            dependencies: [
                "ObservableViewModelMacros",
                .product(name: "FactoryKit", package: "Factory")
            ],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "ObservableViewModelTests",
            dependencies: [
                "ObservableViewModel",
                .product(name: "FactoryKit", package: "Factory")
            ],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
