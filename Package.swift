// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NumberTheoryCore",
    platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "NumberTheoryCore", targets: ["NumberTheoryCore"])],
    targets: [
        .target(name: "NumberTheoryCore", resources: [.process("Reference/course-library.json")]),
        .testTarget(name: "NumberTheoryCoreTests", dependencies: ["NumberTheoryCore"],
                    resources: [.process("Fixtures")])
    ]
)
