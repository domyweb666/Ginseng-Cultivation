// swift-tools-version: 5.10
import PackageDescription

// 規則引擎：純 Swift、只 import Foundation，iOS 與 Linux 都要能跑測試（規矩檔第 1 節）。
let package = Package(
    name: "RencanCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RencanCore", targets: ["RencanCore"])
    ],
    targets: [
        .target(name: "RencanCore"),
        .testTarget(
            name: "RencanCoreTests",
            dependencies: ["RencanCore"],
            // 黃金集的假資料與答案（片 B2），測試用 Bundle.module 讀
            resources: [.copy("Fixtures")]
        ),
    ]
)
