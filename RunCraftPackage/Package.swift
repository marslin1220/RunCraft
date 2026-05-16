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
        .library(name: "TrainingPlanFeature", targets: ["TrainingPlanFeature"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "WatchAppFeature", targets: ["WatchAppFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", from: "1.1.0"),
    ],
    targets: [
        // MARK: - Core Logic

        .target(name: "VDOTEngine"),

        .target(
            name: "HealthKitClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),

        .target(
            name: "RunCraftModels",
            dependencies: [
                "VDOTEngine",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
            ]
        ),

        // MARK: - Features

        .target(
            name: "TrainingPlanFeature",
            dependencies: [
                "VDOTEngine",
                "HealthKitClient",
                "RunCraftModels",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        .target(
            name: "AppFeature",
            dependencies: [
                "TrainingPlanFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        .target(
            name: "WatchAppFeature",
            dependencies: [
                "TrainingPlanFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "VDOTEngineTests",
            dependencies: ["VDOTEngine"]
        ),

        .testTarget(
            name: "TrainingPlanFeatureTests",
            dependencies: [
                "TrainingPlanFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
