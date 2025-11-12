// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Slang",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Slang",
            targets: ["Slang"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SlangBinary",
            url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v2025.22/SlangCompiler.xcframework.zip",
            checksum: "84ffb5cf3f7837faeb7d2b1bd6bb4b5b6dc8d4687da62b978fc4e6d5aeebf209"
        ),

        .target(
            name: "Slang",
            dependencies: ["SlangBinary"],
            path: "Sources/Slang",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("SLANG_DYNAMIC", to: "0"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
