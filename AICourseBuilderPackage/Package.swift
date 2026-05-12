// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AICourseBuilderPackage",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
    ],
    products: [
        .library(name: "LearningModels", targets: ["LearningModels"]),
        .library(name: "LearningDatabase", targets: ["LearningDatabase"]),
        .library(name: "LearningRepository", targets: ["LearningRepository"]),
        .library(name: "LearningUI", targets: ["LearningUI"]),
        .library(name: "LessonRendering", targets: ["LessonRendering"]),
        .library(name: "PlanningEngine", targets: ["PlanningEngine"]),
        .library(name: "EvaluationEngine", targets: ["EvaluationEngine"]),
        .library(name: "AdaptationEngine", targets: ["AdaptationEngine"]),
        .library(name: "TutorEngine", targets: ["TutorEngine"]),
        .library(name: "ChatClients", targets: ["ChatClients"]),
        .library(name: "AppFeature", targets: ["AppFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/sqlite-data", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        // Markdown + LaTeX math rendering for `Concept.body`, `Example.prose`,
        // and other body fields. Spiritual successor to swift-markdown-ui by
        // the same author; native rendering (no WebView), MIT licensed.
        // Math via `$...$` (inline) and `$$...$$` (block) when the `.math`
        // syntax extension is passed.
        .package(url: "https://github.com/gonzalezreal/textual", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "LearningModels",
            dependencies: [
                .product(name: "SQLiteData", package: "sqlite-data"),
            ]
        ),
        .target(
            name: "LearningDatabase",
            dependencies: [
                "LearningModels",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "LearningRepository",
            dependencies: [
                "LearningModels",
                .product(name: "SQLiteData", package: "sqlite-data"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "LearningUI",
            dependencies: [
                .product(name: "Textual", package: "textual"),
            ]
        ),
        .target(
            name: "LessonRendering",
            dependencies: [
                "LearningModels",
                "LearningUI",
                .product(name: "Textual", package: "textual"),
            ]
        ),
        .target(
            name: "PlanningEngine",
            dependencies: [
                "LearningModels",
                "LearningRepository",
                "ChatClients",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "EvaluationEngine",
            dependencies: [
                "LearningModels",
                "LearningRepository",
                "ChatClients",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "AdaptationEngine",
            dependencies: [
                "LearningModels",
                "LearningRepository",
                "ChatClients",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "TutorEngine",
            dependencies: [
                "LearningModels",
                "ChatClients",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "ChatClients",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "AppFeature",
            dependencies: [
                "LearningModels",
                "LearningDatabase",
                "LearningRepository",
                "LearningUI",
                "LessonRendering",
                "AdaptationEngine",
                "EvaluationEngine",
                "PlanningEngine",
                "TutorEngine",
                "ChatClients",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ]
        ),
        .testTarget(
            name: "AICourseBuilderPackageTests",
            dependencies: [
                "AdaptationEngine",
                "AppFeature",
                "ChatClients",
                "EvaluationEngine",
                "LearningDatabase",
                "LearningModels",
                "LearningRepository",
                "LessonRendering",
                "PlanningEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SQLiteData", package: "sqlite-data"),
            ]
        ),
    ]
)
