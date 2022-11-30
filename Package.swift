// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "TCA-Backport-Navigation",
    platforms: [
        .iOS(.v14),
        .tvOS(.v15),
    ],
    products: [
        .library(
            name: "TCA-Backport-Navigation",
            targets: ["TCA-Backport-Navigation"]
		),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "0.47.2"
        ),
        .package(
            url: "https://github.com/pointfreeco/swiftui-navigation",
            from: "0.4.2"
        ),
        .package(
            url: "https://github.com/siteline/SwiftUI-Introspect",
            from: "0.1.4"
        ),
    ],
    targets: [
        .target(
            name: "TCA-Backport-Navigation",
            dependencies: [
                .product(
                    name: "SwiftUINavigation",
                    package: "swiftui-navigation"
                ),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
                .product(
                    name: "Introspect",
                    package: "SwiftUI-Introspect"
                ),
            ]
        )
    ]
)
