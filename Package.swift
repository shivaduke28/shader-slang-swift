// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlangCompiler",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SlangCompiler",
            targets: ["SlangCompiler"]
        ),
    ],
    targets: [
        // Binary XCFramework (GitHub Releasesから取得)
        // TODO: ビルド後にURLとchecksumを更新してください
        .binaryTarget(
            name: "SlangCompilerBinary",
            url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v0.0.1/SlangCompiler.xcframework.zip",
            checksum: "2b44d91c24899e6a2806ee9307c5395b1b9a2fdf98261f5fa2d38e3e6919df97"
        ),

        // Wrapper target (Objective-C++ bridge)
        .target(
            name: "SlangCompiler",
            dependencies: ["SlangCompilerBinary"],
            path: "Sources/SlangCompiler",
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("include"),
                .define("SLANG_DYNAMIC", to: "0"),
            ],
            linkerSettings: [
                .linkedLibrary("c++"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
