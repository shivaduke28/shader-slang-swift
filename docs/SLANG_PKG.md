# Slang Swift Package作成ガイド

このドキュメントは、SlangコンパイラをSwift Packageとして配布可能にするための完全な手順書です。

## 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [Phase 1: Simulator用ビルド](#phase-1-simulator用ビルド)
4. [Phase 2: XCFramework作成](#phase-2-xcframework作成)
5. [Phase 3: Swift Package新規リポジトリ作成](#phase-3-swift-package新規リポジトリ作成)
6. [Phase 4: GitHub Releases配布](#phase-4-github-releases配布)
7. [Phase 5: Arshes本体への統合](#phase-5-arshes本体への統合)
8. [トラブルシューティング](#トラブルシューティング)

---

## 概要

### 目標

- SlangコンパイラをSwift Package Manager経由で配布
- XCFrameworkを使用して複数プラットフォーム対応
- GitHub Releasesでバイナリ配布（リポジトリサイズ削減）

### アーキテクチャ対応

| プラットフォーム | アーキテクチャ | 状態 |
|-----------------|--------------|------|
| iOS Device | arm64 | ✅ 完了 (SLANG.md参照) |
| iOS Simulator (Apple Silicon) | arm64 | ⏳ TODO |
| iOS Simulator (Intel) | x86_64 | ⏳ TODO |

### 最終成果物

```
SlangCompiler-iOS/  (新規リポジトリ)
├── Package.swift
├── LICENSE (Apache 2.0 with LLVM exception)
├── README.md
└── Sources/
    └── SlangCompiler/
        ├── SlangCompiler.h
        ├── SlangCompiler.mm
        └── SlangCompiler-Bridging-Header.h
```

XCFrameworkはGitHub Releasesで配布し、Package.swiftのbinaryTargetで参照します。

---

## 前提条件

### 必要なツール

```bash
# Xcodeコマンドラインツール
xcode-select --install

# cmake, ninja (既にインストール済みのはず)
brew install cmake ninja
```

### 既存の成果物

- ✅ `experimental/ios.toolchain.cmake` - iOS Device用toolchain
- ✅ `experimental/slang/build-ios/` - iOS Device用ビルド済みライブラリ
- ✅ `experimental/SlangTest/Vendor/Slang/lib-stripped/` - strip済みライブラリ (31MB)

---

## Phase 1: Simulator用ビルド

### 1.1 iOS Simulator (arm64) 用toolchainファイル作成

`experimental/ios-simulator-arm64.toolchain.cmake` を作成:

```cmake
# iOS Simulator (Apple Silicon) CMake Toolchain File
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 17.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET 17.0)

# Target arm64 for iOS Simulator on Apple Silicon
set(CMAKE_OSX_ARCHITECTURES "arm64")

# Set SDK path for iOS Simulator
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Compiler settings
set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)

# Flags for iOS Simulator
set(CMAKE_C_FLAGS_INIT "-mios-simulator-version-min=17.0")
set(CMAKE_CXX_FLAGS_INIT "-mios-simulator-version-min=17.0")

# Find programs on host, libraries/includes in sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Set build type specific flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")
```

**重要**: `-mios-simulator-version-min` フラグがSimulator用には必須です。

### 1.2 iOS Simulator (x86_64) 用toolchainファイル作成

`experimental/ios-simulator-x86_64.toolchain.cmake` を作成:

```cmake
# iOS Simulator (Intel) CMake Toolchain File
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 17.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET 17.0)

# Target x86_64 for iOS Simulator on Intel Mac
set(CMAKE_OSX_ARCHITECTURES "x86_64")

# Set SDK path for iOS Simulator
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Compiler settings
set(CMAKE_C_COMPILER /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)

# Flags for iOS Simulator
set(CMAKE_C_FLAGS_INIT "-mios-simulator-version-min=17.0")
set(CMAKE_CXX_FLAGS_INIT "-mios-simulator-version-min=17.0")

# Find programs on host, libraries/includes in sysroot
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Set build type specific flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")
```

### 1.3 Simulator (arm64) 用ビルド

```bash
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/slang

# ビルドディレクトリを作成
rm -rf build-ios-simulator-arm64
mkdir -p build-ios-simulator-arm64
cd build-ios-simulator-arm64

# CMakeでiOS Simulator (arm64) 向けに設定
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=../../ios-simulator-arm64.toolchain.cmake \
  -DSLANG_GENERATORS_PATH=../generators/bin \
  -DSLANG_LIB_TYPE=STATIC \
  -DSLANG_ENABLE_TESTS=OFF \
  -DSLANG_ENABLE_EXAMPLES=OFF \
  -DSLANG_ENABLE_GFX=OFF \
  -DSLANG_ENABLE_SLANGD=OFF \
  -DSLANG_ENABLE_SLANGC=OFF \
  -DSLANG_ENABLE_SLANGRT=OFF \
  -DSLANG_ENABLE_SLANGI=OFF

# ビルド実行
ninja libslang-compiler.a libcompiler-core.a libcore.a

# 確認
file Release/lib/libslang-compiler.a
# 出力例: Release/lib/libslang-compiler.a: Mach-O 64-bit object arm64

# strip処理
cd Release/lib
strip -S libslang-compiler.a
strip -S libcompiler-core.a
strip -S libcore.a

# miniz, lz4も必要
strip -S ../../external/miniz/libminiz.a
strip -S ../../external/lz4/build/cmake/liblz4.a
```

**所要時間**: 約5〜15分

### 1.4 Simulator (x86_64) 用ビルド

```bash
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/slang

# ビルドディレクトリを作成
rm -rf build-ios-simulator-x86_64
mkdir -p build-ios-simulator-x86_64
cd build-ios-simulator-x86_64

# CMakeでiOS Simulator (x86_64) 向けに設定
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=../../ios-simulator-x86_64.toolchain.cmake \
  -DSLANG_GENERATORS_PATH=../generators/bin \
  -DSLANG_LIB_TYPE=STATIC \
  -DSLANG_ENABLE_TESTS=OFF \
  -DSLANG_ENABLE_EXAMPLES=OFF \
  -DSLANG_ENABLE_GFX=OFF \
  -DSLANG_ENABLE_SLANGD=OFF \
  -DSLANG_ENABLE_SLANGC=OFF \
  -DSLANG_ENABLE_SLANGRT=OFF \
  -DSLANG_ENABLE_SLANGI=OFF

# ビルド実行
ninja libslang-compiler.a libcompiler-core.a libcore.a

# 確認
file Release/lib/libslang-compiler.a
# 出力例: Release/lib/libslang-compiler.a: Mach-O 64-bit object x86_64

# strip処理
cd Release/lib
strip -S libslang-compiler.a
strip -S libcompiler-core.a
strip -S libcore.a

# miniz, lz4も必要
strip -S ../../external/miniz/libminiz.a
strip -S ../../external/lz4/build/cmake/liblz4.a
```

**所要時間**: 約5〜15分

### 1.5 ビルド成果物の整理

```bash
# 作業ディレクトリ作成
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental
mkdir -p xcframework-build/ios-device
mkdir -p xcframework-build/ios-simulator-arm64
mkdir -p xcframework-build/ios-simulator-x86_64

# iOS Device (既存)
cp slang/build-ios/Release/lib/*.a xcframework-build/ios-device/
cp slang/build-ios/external/miniz/libminiz.a xcframework-build/ios-device/
cp slang/build-ios/external/lz4/build/cmake/liblz4.a xcframework-build/ios-device/

# iOS Simulator arm64
cp slang/build-ios-simulator-arm64/Release/lib/*.a xcframework-build/ios-simulator-arm64/
cp slang/build-ios-simulator-arm64/external/miniz/libminiz.a xcframework-build/ios-simulator-arm64/
cp slang/build-ios-simulator-arm64/external/lz4/build/cmake/liblz4.a xcframework-build/ios-simulator-arm64/

# iOS Simulator x86_64
cp slang/build-ios-simulator-x86_64/Release/lib/*.a xcframework-build/ios-simulator-x86_64/
cp slang/build-ios-simulator-x86_64/external/miniz/libminiz.a xcframework-build/ios-simulator-x86_64/
cp slang/build-ios-simulator-x86_64/external/lz4/build/cmake/liblz4.a xcframework-build/ios-simulator-x86_64/

# 確認
ls -lh xcframework-build/*/
```

---

## Phase 2: XCFramework作成

### 2.1 Simulator用 Fat Binary作成

iOS Simulatorは arm64 と x86_64 の両方をサポートする必要があるため、まず2つを統合します。

```bash
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/xcframework-build

# Simulator用ディレクトリ作成
mkdir -p ios-simulator

# 各ライブラリをlipoで統合
lipo -create \
  ios-simulator-arm64/libslang-compiler.a \
  ios-simulator-x86_64/libslang-compiler.a \
  -output ios-simulator/libslang-compiler.a

lipo -create \
  ios-simulator-arm64/libcompiler-core.a \
  ios-simulator-x86_64/libcompiler-core.a \
  -output ios-simulator/libcompiler-core.a

lipo -create \
  ios-simulator-arm64/libcore.a \
  ios-simulator-x86_64/libcore.a \
  -output ios-simulator/libcore.a

lipo -create \
  ios-simulator-arm64/libminiz.a \
  ios-simulator-x86_64/libminiz.a \
  -output ios-simulator/libminiz.a

lipo -create \
  ios-simulator-arm64/liblz4.a \
  ios-simulator-x86_64/liblz4.a \
  -output ios-simulator/liblz4.a

# 確認
lipo -info ios-simulator/libslang-compiler.a
# 出力例: Architectures in the fat file: ios-simulator/libslang-compiler.a are: x86_64 arm64
```

### 2.2 XCFramework作成

XCFrameworkは静的ライブラリの集合体として作成します。

```bash
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/xcframework-build

# 各ライブラリ用のXCFrameworkを作成
# 1. libslang-compiler
xcodebuild -create-xcframework \
  -library ios-device/libslang-compiler.a \
  -library ios-simulator/libslang-compiler.a \
  -output SlangCompiler.xcframework

# 2. libcompiler-core
xcodebuild -create-xcframework \
  -library ios-device/libcompiler-core.a \
  -library ios-simulator/libcompiler-core.a \
  -output CompilerCore.xcframework

# 3. libcore
xcodebuild -create-xcframework \
  -library ios-device/libcore.a \
  -library ios-simulator/libcore.a \
  -output Core.xcframework

# 4. libminiz
xcodebuild -create-xcframework \
  -library ios-device/libminiz.a \
  -library ios-simulator/libminiz.a \
  -output Miniz.xcframework

# 5. liblz4
xcodebuild -create-xcframework \
  -library ios-device/liblz4.a \
  -library ios-simulator/liblz4.a \
  -output LZ4.xcframework

# 確認
ls -lh *.xcframework
```

### 2.3 XCFrameworkの検証

```bash
# 構造確認
find SlangCompiler.xcframework -type f

# 期待される出力:
# SlangCompiler.xcframework/Info.plist
# SlangCompiler.xcframework/ios-arm64/libslang-compiler.a
# SlangCompiler.xcframework/ios-arm64_x86_64-simulator/libslang-compiler.a

# アーキテクチャ確認
lipo -info SlangCompiler.xcframework/ios-arm64/libslang-compiler.a
# 出力: Non-fat file: ... is architecture: arm64

lipo -info SlangCompiler.xcframework/ios-arm64_x86_64-simulator/libslang-compiler.a
# 出力: Architectures in the fat file: ... are: x86_64 arm64
```

### 2.4 配布用アーカイブ作成

```bash
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/xcframework-build

# 全てのXCFrameworkをzip化
zip -r SlangCompiler-iOS.xcframework.zip \
  SlangCompiler.xcframework \
  CompilerCore.xcframework \
  Core.xcframework \
  Miniz.xcframework \
  LZ4.xcframework

# サイズ確認
ls -lh SlangCompiler-iOS.xcframework.zip
# 期待: 約45〜60MB (3アーキテクチャ分)

# checksumを計算（後でPackage.swiftに記載）
swift package compute-checksum SlangCompiler-iOS.xcframework.zip
# 出力例: a1b2c3d4e5f6...
```

**重要**: このchecksumは後でPackage.swiftに記載します。

---

## Phase 3: Swift Package新規リポジトリ作成

### 3.1 新規リポジトリ作成

GitHubで新規リポジトリを作成します:

- **リポジトリ名**: `SlangCompiler-iOS` (推奨)
- **説明**: "Slang Shader Language Compiler for iOS - Swift Package"
- **公開設定**: Public or Private（お好みで）
- **ライセンス**: Apache 2.0 with LLVM exception（Slangと同じ）

```bash
# ローカルにクローン
cd ~/ghq/github.com/shivaduke28
git clone https://github.com/shivaduke28/SlangCompiler-iOS.git
cd SlangCompiler-iOS
```

### 3.2 ディレクトリ構成作成

```bash
cd SlangCompiler-iOS

# ディレクトリ作成
mkdir -p Sources/SlangCompiler

# ファイルをコピー
cp /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/SlangTest/SlangTest/SlangCompiler.h \
   Sources/SlangCompiler/

cp /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/SlangTest/SlangTest/SlangCompiler.mm \
   Sources/SlangCompiler/

cp /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/SlangTest/SlangTest/SlangTest-Bridging-Header.h \
   Sources/SlangCompiler/SlangCompiler-Bridging-Header.h

# Slangのヘッダーもコピー（必要に応じて）
cp -r /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/SlangTest/Vendor/Slang/include \
      Sources/SlangCompiler/include
```

### 3.3 Package.swift作成

`Package.swift` を以下の内容で作成:

```swift
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
            targets: ["SlangCompiler", "SlangCompilerWrapper"]
        ),
    ],
    targets: [
        // Binary XCFrameworks (GitHub Releasesから取得)
        .binaryTarget(
            name: "SlangCompilerBinary",
            url: "https://github.com/shivaduke28/SlangCompiler-iOS/releases/download/v1.0.0/SlangCompiler-iOS.xcframework.zip",
            checksum: "YOUR_CHECKSUM_HERE" // Phase 2.4で計算したchecksum
        ),

        // Wrapper target (Objective-C++ bridge)
        .target(
            name: "SlangCompilerWrapper",
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

        // Swift wrapper (if needed)
        .target(
            name: "SlangCompiler",
            dependencies: ["SlangCompilerWrapper"]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
```

**注意事項**:
1. `url` は実際のGitHub ReleasesのURLに置き換える
2. `checksum` はPhase 2.4で計算した値に置き換える
3. バージョン番号（v1.0.0）は適宜変更

### 3.4 LICENSE作成

Slangのライセンスをコピー:

```bash
cd SlangCompiler-iOS
cp /Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/slang/LICENSE .
```

### 3.5 README.md作成

`README.md` を作成:

```markdown
# SlangCompiler for iOS

Slang Shader Language Compiler for iOS - Swift Package

## About

This package provides [Slang](https://github.com/shader-slang/slang) shader compiler for iOS applications. Slang is a shader language that compiles to multiple targets including Metal Shading Language (MSL).

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shivaduke28/SlangCompiler-iOS.git", from: "1.0.0")
]
```

Or add it via Xcode:
1. File → Add Packages...
2. Enter: `https://github.com/shivaduke28/SlangCompiler-iOS.git`

## Usage

```swift
import SlangCompiler

let compiler = SlangCompiler()

let slangSource = """
[shader("vertex")]
float4 vertexMain(float3 pos : POSITION) : SV_Position
{
    return float4(pos, 1.0);
}
"""

do {
    let mslCode = try compiler.compileSlang(toMSL: slangSource, entryPoint: "vertexMain")
    print(mslCode)
} catch {
    print("Compilation failed: \(error)")
}
```

## Requirements

- iOS 17.0+
- Xcode 15.0+

## License

Apache 2.0 with LLVM exception (same as Slang)

See [LICENSE](LICENSE) for details.

## Credits

This package wraps the [Slang shader compiler](https://github.com/shader-slang/slang) developed by NVIDIA and the Khronos Group.
```

---

## Phase 4: GitHub Releases配布

### 4.1 初回コミット

```bash
cd SlangCompiler-iOS

git add .
git commit -m "Initial commit: SlangCompiler Swift Package

- Add SlangCompiler.h/mm (Objective-C++ bridge)
- Add Package.swift with binaryTarget placeholder
- Add LICENSE (Apache 2.0 with LLVM exception)
- Add README with usage instructions"

git push origin main
```

### 4.2 タグ作成

```bash
cd SlangCompiler-iOS

# バージョンタグを作成
git tag -a v1.0.0 -m "Release v1.0.0

First release of SlangCompiler for iOS
- Support iOS Device (arm64)
- Support iOS Simulator (arm64, x86_64)
- XCFramework distribution via GitHub Releases"

git push origin v1.0.0
```

### 4.3 GitHub Releasesでリリース作成

1. GitHubの `SlangCompiler-iOS` リポジトリページへアクセス
2. **Releases** → **Create a new release** をクリック
3. **Choose a tag**: `v1.0.0` を選択
4. **Release title**: `v1.0.0`
5. **Description**: 以下を記載

```markdown
## SlangCompiler v1.0.0

First stable release of Slang Shader Language Compiler for iOS.

### Features
- ✅ Compile Slang shaders to Metal Shading Language (MSL) at runtime
- ✅ Support iOS Device (arm64)
- ✅ Support iOS Simulator (arm64 for Apple Silicon, x86_64 for Intel)
- ✅ XCFramework distribution
- ✅ Swift Package Manager integration

### Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shivaduke28/SlangCompiler-iOS.git", from: "1.0.0")
]
```

### Binary Size
- Total: ~55MB (compressed)
- Includes all required libraries (libslang-compiler, libcompiler-core, libcore, libminiz, liblz4)

### License
Apache 2.0 with LLVM exception
```

6. **Attach binaries**: `SlangCompiler-iOS.xcframework.zip` をアップロード
   - `/Users/shivaduke/ghq/github.com/shivaduke28/Arshes/experimental/xcframework-build/SlangCompiler-iOS.xcframework.zip`

7. **Publish release** をクリック

### 4.4 Release URLとchecksum更新

リリース作成後、バイナリのURLを確認:

```
https://github.com/shivaduke28/SlangCompiler-iOS/releases/download/v1.0.0/SlangCompiler-iOS.xcframework.zip
```

`Package.swift` を更新:

```swift
.binaryTarget(
    name: "SlangCompilerBinary",
    url: "https://github.com/shivaduke28/SlangCompiler-iOS/releases/download/v1.0.0/SlangCompiler-iOS.xcframework.zip",
    checksum: "a1b2c3d4e5f6..." // Phase 2.4で計算した実際のchecksum
),
```

コミット:

```bash
git add Package.swift
git commit -m "Update Package.swift with release URL and checksum"
git push origin main
```

---

## Phase 5: Arshes本体への統合

### 5.1 Package依存追加

Arshesプロジェクトが既にSwift Package Managerを使用している場合:

`Package.swift` に追加:

```swift
dependencies: [
    .package(url: "https://github.com/shivaduke28/SlangCompiler-iOS.git", from: "1.0.0"),
    // ... 他の依存関係
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SlangCompiler", package: "SlangCompiler-iOS"),
            // ... 他の依存関係
        ]
    ),
]
```

Xcodeプロジェクトの場合:

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーターでプロジェクトを選択
3. **Package Dependencies** タブを選択
4. **+** ボタンをクリック
5. URL入力: `https://github.com/shivaduke28/SlangCompiler-iOS.git`
6. バージョン選択: `1.0.0` 〜
7. **Add Package** をクリック

### 5.2 既存コードの移行

SlangTestのコードをArshes本体に移行する場合:

**Before** (SlangTest):
```swift
import UIKit

let compiler = SlangCompiler()
let msl = try compiler.compileSlang(toMSL: source, entryPoint: "main")
```

**After** (Arshes with Package):
```swift
import SlangCompiler

let compiler = SlangCompiler()
let msl = try compiler.compileSlang(toMSL: source, entryPoint: "main")
```

**変更点**:
- `import SlangCompiler` を追加
- 他のコードは変更不要（APIは同一）

### 5.3 ビルド設定確認

Xcode設定の確認:

1. **Build Settings** で以下を確認:
   - **C++ Language Dialect**: GNU++17 以上
   - **C++ Standard Library**: libc++
   - **Enable C++ Runtime Types**: Yes

2. **Signing & Capabilities** で必要に応じて設定

### 5.4 experimental/SlangTestの整理

Arshes本体への統合が完了したら、実験用プロジェクトは削除またはアーカイブ:

```bash
# オプション1: 削除
cd /Users/shivaduke/ghq/github.com/shivaduke28/Arshes
rm -rf experimental/SlangTest

# オプション2: アーカイブ（推奨）
mv experimental/SlangTest experimental/SlangTest.archive
```

---

## トラブルシューティング

### エラー1: アーキテクチャミスマッチ

**症状**:
```
ld: building for 'iOS-simulator', but linking in object file built for 'iOS'
```

**原因**: XCFrameworkが正しく認識されていない

**解決策**:
1. XCFrameworkの構造を確認:
```bash
find SlangCompiler.xcframework -name "*.a" -exec lipo -info {} \;
```

2. Xcode の **Build Settings** → **Excluded Architectures** を確認
3. クリーンビルド: Shift + Cmd + K

### エラー2: Undefined symbols for architecture

**症状**:
```
Undefined symbol: slang::createGlobalSession(...)
```

**原因**: 必要なライブラリがリンクされていない

**解決策**:
1. すべてのXCFrameworkがPackage.swiftに含まれているか確認
2. **Other Linker Flags** に `-lc++` が含まれているか確認

### エラー3: checksum不一致

**症状**:
```
checksum of downloaded artifact of binary target 'SlangCompilerBinary' does not match checksum specified
```

**原因**: Package.swiftのchecksumが間違っている

**解決策**:
1. 正しいchecksumを再計算:
```bash
swift package compute-checksum SlangCompiler-iOS.xcframework.zip
```

2. Package.swiftを更新してコミット

### エラー4: 'slang.h' file not found

**症状**:
```
'slang.h' file not found
```

**原因**: ヘッダーファイルのパスが正しくない

**解決策**:
1. `Sources/SlangCompiler/include/` にヘッダーが存在するか確認
2. Package.swiftの `headerSearchPath` を確認:
```swift
cxxSettings: [
    .headerSearchPath("include"),
]
```

### エラー5: ビルド時のメモリ不足

**症状**: Xcodeがフリーズ、またはビルドが途中で止まる

**原因**: XCFrameworkのサイズが大きい

**解決策**:
1. Xcodeを再起動
2. DerivedData削除:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

3. ビルド設定で並列ビルド数を減らす

---

## 参考資料

- [Slang公式ドキュメント](https://shader-slang.org/)
- [Slang GitHubリポジトリ](https://github.com/shader-slang/slang)
- [Apple XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Swift Package Manager Documentation](https://www.swift.org/package-manager/)

---

## 作業履歴

- **2025-11-02**: ドキュメント作成
- **TODO**: Simulator用ビルド実施
- **TODO**: XCFramework作成
- **TODO**: Swift Package公開

---

## ライセンス

このドキュメントはArshesプロジェクトの一部です。

Slang自体は **Apache 2.0 with LLVM exception** ライセンスです。
