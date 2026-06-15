// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RunCraftPackage",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v13),
    ],
    products: [
        .library(name: "VDOTEngine", targets: ["VDOTEngine"]),
        .library(name: "HealthKitClient", targets: ["HealthKitClient"]),
        .library(name: "RunCraftModels", targets: ["RunCraftModels"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "TrainingPlanFeature", targets: ["TrainingPlanFeature"]),
        .library(name: "AppleWatchSync", targets: ["AppleWatchSync"]),
        .library(name: "WorkshopFeature", targets: ["WorkshopFeature"]),
        .library(name: "InsightsFeature", targets: ["InsightsFeature"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "RunCraftIntents", targets: ["RunCraftIntents"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0"),
    ],
    targets: [
        // MARK: - Core Logic

        .target(
            name: "VDOTEngine",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "HealthKitClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "RunCraftModels",
            dependencies: [
                "VDOTEngine",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        // MARK: - UI

        .target(name: "DesignSystem"),

        // MARK: - Features

        .target(
            name: "TrainingPlanFeature",
            dependencies: [
                "AppleWatchSync",
                "DesignSystem",
                "VDOTEngine",
                "HealthKitClient",
                "RunCraftModels",
                "WorkshopFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "AppleWatchSync",
            dependencies: [
                "RunCraftModels",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "WorkshopFeature",
            dependencies: [
                "AppleWatchSync",
                "DesignSystem",
                "VDOTEngine",
                "RunCraftModels",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "InsightsFeature",
            dependencies: [
                "DesignSystem",
                "HealthKitClient",
                "RunCraftModels",
                "VDOTEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        .target(
            name: "AppFeature",
            dependencies: [
                "DesignSystem",
                "HealthKitClient",
                "InsightsFeature",
                "RunCraftIntents",
                "TrainingPlanFeature",
                "VDOTEngine",
                "WorkshopFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        // MARK: - App Intents (Siri / Spotlight / Apple Intelligence)

        .target(
            name: "RunCraftIntents",
            dependencies: [
                "AppleWatchSync",
                "DesignSystem",
                "RunCraftModels",
                "VDOTEngine",
                "WorkshopFeature",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),

        // MARK: - Tests

        .testTarget(
            name: "VDOTEngineTests",
            dependencies: ["VDOTEngine"]
        ),

        .testTarget(
            name: "RunCraftModelsTests",
            dependencies: [
                "RunCraftModels",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),

        .testTarget(
            name: "AppleWatchSyncTests",
            dependencies: ["AppleWatchSync"]
        ),

        .testTarget(
            name: "TrainingPlanFeatureTests",
            dependencies: [
                "TrainingPlanFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),

        .testTarget(
            name: "WorkshopFeatureTests",
            dependencies: [
                "WorkshopFeature",
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
    ]
)
