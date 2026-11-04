// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IrisCamMonitor",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "IrisCamMonitor", targets: ["IrisCamMonitor"])],
    targets: [.executableTarget(name: "IrisCamMonitor")]
)
