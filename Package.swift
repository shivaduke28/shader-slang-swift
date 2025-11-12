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
            url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v0.0.1/SlangCompiler.xcframework.zip",
            checksum: "2b44d91c24899e6a2806ee9307c5395b1b9a2fdf98261f5fa2d38e3e6919df97"
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
