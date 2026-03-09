// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShiftInputSwitch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ShiftInputSwitch", targets: ["ShiftKeyIMESwitch"])
    ],
    targets: [
        .executableTarget(
            name: "ShiftKeyIMESwitch",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
