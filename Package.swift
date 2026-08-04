// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LRExportHEIC",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "LRExportHEIC",
      exclude: ["Info.plist"],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist",
          "-Xlinker", "Sources/LRExportHEIC/Info.plist",
        ])
      ]
    ),
    .testTarget(
      name: "LRExportHEICTests",
      dependencies: ["LRExportHEIC"]),
  ]
)
