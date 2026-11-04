// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "VioraCore", platforms: [.macOS(.v14), .iOS(.v17)], products: [.library(name: "VioraCore", targets: ["VioraCore"])], targets: [.target(name: "VioraCore"), .testTarget(name: "VioraCoreTests", dependencies: ["VioraCore"])])
