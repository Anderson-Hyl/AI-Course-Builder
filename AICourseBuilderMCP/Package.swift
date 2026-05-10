// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AICourseBuilderMCP",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "AICourseBuilderMCPServer",
            targets: ["AICourseBuilderMCPServer"]
        )
    ],
    dependencies: [
        // Official Model Context Protocol Swift SDK. Provides `Server`,
        // `StatefulHTTPServerTransport`, `Tool`, and the JSON-RPC layer we
        // expose to the local Claude Code CLI subprocess.
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk",
            from: "0.12.0"
        ),
        // Hummingbird 2 for the HTTP frontend. The swift-sdk provides the
        // MCP transport; Hummingbird routes POST/GET/DELETE /mcp into it.
        .package(
            url: "https://github.com/hummingbird-project/hummingbird",
            from: "2.0.0"
        ),
        // Sibling package — depends on its `ChatClients` target for
        // `MCPCallSession`, `MCPServerState`, and `ToolSpec`.
        .package(path: "../AICourseBuilderPackage"),
    ],
    targets: [
        .target(
            name: "AICourseBuilderMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "ChatClients", package: "AICourseBuilderPackage"),
            ]
        )
    ]
)
