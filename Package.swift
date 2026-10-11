// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowTranslate",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "FlowTranslate", targets: ["FlowTranslate"])],
    targets: [
        .target(name: "FlowCore"),
        .executableTarget(name: "FlowTranslate", dependencies: ["FlowCore"]),
        .executableTarget(name: "FlowCoreChecks", dependencies: ["FlowCore"], path: "Tests/FlowCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
