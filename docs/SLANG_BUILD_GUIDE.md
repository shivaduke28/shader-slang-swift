# Slang iOS Build & Integration Guide

このドキュメントは、Slang Shader Compilerを iOS向けにビルドし、Swift Packageとして配布するための完全なガイドです。

## 目次

1. [概要](#概要)
2. [前提条件](#前提条件)
3. [ビルドシステム](#ビルドシステム)
4. [iOS向けビルド手順](#ios向けビルド手順)
5. [Objective-C++ブリッジ](#objective-cブリッジ)
6. [Swift Package配布](#swift-package配布)
7. [動作確認とテスト](#動作確認とテスト)
8. [トラブルシューティング](#トラブルシューティング)
9. [参考資料](#参考資料)

---

## 概要

### Slangとは

[Slang](https://shader-slang.org/)は、複数のプラットフォーム向けにシェーダーをコンパイルできるモダンなシェーダー言語です:

- **Metal (MSL)** - iOS/macOS
- **SPIR-V** - Vulkan
- **HLSL** - DirectX
- **WGSL** - WebGPU
- **CUDA/C++** - CPU/GPU Compute

### このプロジェクトの目標

- ✅ SlangコンパイラをiOS向けに静的ライブラリとしてビルド
- ✅ 複数ライブラリを1つのXCFrameworkに統合
- ✅ Swift Package Manager経由で配布
- ✅ GitHub Releasesでバイナリ配布（リポジトリサイズ削減）
- ✅ ランタイムでSlangからMSLへのコンパイルを実現

### アーキテクチャ対応

| プラットフォーム | アーキテクチャ | 状態 |
|-----------------|--------------|------|
| iOS Device | arm64 | ✅ サポート |
| iOS Simulator (Apple Silicon) | arm64 | ✅ サポート |
| iOS Simulator (Intel) | x86_64 | ❌ 非対応 |

**注意**: Intelベースのシミュレーターは非対応です。Apple Siliconでの開発を推奨します。

### プロジェクト構成

```
shader-slang-swift/
├── Package.swift               # Swift Package定義
├── Makefile                    # ビルド自動化
├── README.md                   # ユーザー向けドキュメント
├── docs/
│   ├── IMPLEMENTATION_PLAN.md  # 実装計画
│   └── SLANG_BUILD_GUIDE.md    # このファイル
├── slang/                      # Slangサブモジュール（開発者用）
├── toolchains/                 # CMake toolchainファイル
│   ├── ios-device.toolchain.cmake
│   └── ios-simulator-arm64.toolchain.cmake
├── Sources/SlangCompiler/      # Objective-C++ブリッジ
│   ├── SlangCompiler.h
│   ├── SlangCompiler.mm
│   ├── SlangTest-Bridging-Header.h
│   └── include/                # Slangヘッダー
├── build/                      # ビルド成果物（.gitignore）
└── xcframework/                # XCFramework（.gitignore）
```

---

## 前提条件

### 開発環境

- **macOS**: Apple Silicon推奨（Intelでも可）
- **Xcode**: 15.0以上
- **Command Line Tools**: `xcode-select --install`
- **CMake**: 3.26以上
- **Ninja**: ビルドシステム

### 依存ツールのインストール

```bash
# Homebrewでインストール
brew install cmake ninja

# バージョン確認
cmake --version    # 3.26以上
ninja --version    # 1.11以上
xcodebuild -version # Xcode 15.0以上
```

### リポジトリのクローン

```bash
# サブモジュールを含めてクローン
git clone --recursive https://github.com/shivaduke28/shader-slang-swift.git
cd shader-slang-swift

# 既にクローン済みの場合はサブモジュールを更新
git submodule update --init --recursive
```

---

## ビルドシステム

### Makefileによる自動化

このプロジェクトでは、複雑なビルドプロセスをMakefileで自動化しています。

#### 利用可能なターゲット

```bash
make help        # ヘルプ表示
make all         # 全自動ビルド（推奨）
make generators  # コード生成ツールのビルド（ホスト環境）
make device      # iOS Device向けビルド
make simulator   # iOS Simulator向けビルド
make build       # deviceとsimulatorの両方
make xcframework # XCFramework作成
make archive     # 配布用zipアーカイブ作成
make verify      # ビルド成果物の検証
make clean       # ビルド成果物の削除
```

#### 推奨ワークフロー

```bash
# 全自動ビルド（初回は10〜30分かかります）
make all
```

これにより以下が自動実行されます:
1. generatorsビルド（ホスト環境用）
2. iOS Deviceビルド
3. iOS Simulatorビルド
4. ライブラリのマージ（1つの静的ライブラリに統合）
5. XCFramework作成
6. 配布用zipアーカイブ＋checksum生成

### CMake Toolchainファイル

#### iOS Device用 (`toolchains/ios-device.toolchain.cmake`)

```cmake
set(CMAKE_SYSTEM_NAME iOS)
set(CMAKE_SYSTEM_VERSION 17.0)
set(CMAKE_OSX_DEPLOYMENT_TARGET 17.0)
set(CMAKE_OSX_ARCHITECTURES "arm64")

execute_process(
    COMMAND xcrun --sdk iphoneos --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND xcrun --find clang
    OUTPUT_VARIABLE CMAKE_C_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND xcrun --find clang++
    OUTPUT_VARIABLE CMAKE_CXX_COMPILER
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CMAKE_C_FLAGS_INIT "-mios-version-min=17.0")
set(CMAKE_CXX_FLAGS_INIT "-mios-version-min=17.0")
```

**ポイント**:
- `xcrun`を使ってSDKとコンパイラパスを動的に取得
- iOS 17.0以降をターゲット
- arm64アーキテクチャのみ

#### iOS Simulator用 (`toolchains/ios-simulator-arm64.toolchain.cmake`)

```cmake
# Device用と同様だが以下が異なる:
execute_process(
    COMMAND xcrun --sdk iphonesimulator --show-sdk-path
    OUTPUT_VARIABLE CMAKE_OSX_SYSROOT
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

set(CMAKE_C_FLAGS_INIT "-mios-simulator-version-min=17.0")
set(CMAKE_CXX_FLAGS_INIT "-mios-simulator-version-min=17.0")
```

**重要な違い**:
- SDK: `iphonesimulator`（Device版は`iphoneos`）
- フラグ: `-mios-simulator-version-min`（Device版は`-mios-version-min`）

---

## iOS向けビルド手順

### Phase 1: Generators（コード生成ツール）のビルド

Slangはクロスコンパイル時に、ホスト環境（macOS）用のコード生成ツールが必要です。

```bash
make generators
```

**所要時間**: 初回5〜20分

**生成される成果物**:
- `slang/generators/generators/Release/bin/slang-generate`
- `slang/generators/generators/Release/bin/slang-embed`
- その他のコード生成ツール

**スキップ条件**: `slang/generators/generators/bin/`が存在する場合はスキップされます。

### Phase 2: iOS Device向けビルド

```bash
make device
```

**処理内容**:
1. CMakeでiOS Device向けに設定
2. Ninjaでコンパイル（980タスク程度）
3. 以下のライブラリを生成:
   - `libslang-compiler.a` - メインコンパイラ
   - `libcompiler-core.a` - コンパイラコア
   - `libcore.a` - コアユーティリティ
   - `libminiz.a` - zip圧縮ライブラリ
   - `liblz4.a` - lz4圧縮ライブラリ
4. `strip -S`でデバッグシンボル削除（サイズ削減）
5. `libtool`で5つのライブラリを1つにマージ

**所要時間**: 5〜15分

**生成される成果物**:
- `build/ios-device/libSlangCompiler.a` - マージ済み静的ライブラリ

### Phase 3: iOS Simulator向けビルド

```bash
make simulator
```

**処理内容**: Phase 2と同様ですが、iOS Simulator向けにビルド

**生成される成果物**:
- `build/ios-simulator-arm64/libSlangCompiler.a`

### Phase 4: XCFramework作成

```bash
make xcframework
```

**処理内容**:
1. 2つのプラットフォーム用ライブラリを統合
2. XCFramework形式で出力

**生成される成果物**:
- `xcframework/SlangCompiler.xcframework/`
  - `ios-arm64/libSlangCompiler.a` - iOS Device用
  - `ios-arm64-simulator/libSlangCompiler.a` - iOS Simulator用

### Phase 5: 配布用アーカイブ作成

```bash
make archive
```

**処理内容**:
1. XCFrameworkをzip圧縮
2. `swift package compute-checksum`でchecksum計算

**生成される成果物**:
- `xcframework/SlangCompiler.xcframework.zip` - 配布用アーカイブ（約50〜60MB）
- `xcframework/SlangCompiler.xcframework.zip.checksum` - Package.swift用checksum

### ビルド成果物のサイズ

| ライブラリ | ビルド直後 | strip後 |
|-----------|-----------|---------|
| libslang-compiler.a | 976MB | 29MB |
| libcompiler-core.a | 17MB | 1.1MB |
| libcore.a | 8.3MB | 826KB |
| libminiz.a | 97KB | 95KB |
| liblz4.a | 158KB | 157KB |
| **合計（1プラットフォーム）** | **1.0GB** | **31MB** |

**重要**: `strip -S`でデバッグシンボルを削除することで**97%のサイズ削減**を実現しています。

---

## Objective-C++ブリッジ

SlangはC++ APIを提供していますが、iOSアプリからはSwiftで使いたいため、Objective-C++によるブリッジを実装しています。

### ファイル構成

```
Sources/SlangCompiler/
├── SlangCompiler.h                  # Objective-Cインターフェース
├── SlangCompiler.mm                 # Slang C++ APIラッパー
├── SlangTest-Bridging-Header.h      # Swift連携用
└── include/                          # Slangヘッダー
    ├── slang.h
    ├── slang-com-ptr.h
    └── slang-com-helper.h
```

### SlangCompiler.h

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SlangCompiler : NSObject

- (nullable NSString *)compileSlangToMSL:(NSString *)slangSource
                              entryPoint:(NSString *)entryPointName
                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
```

### SlangCompiler.mm - 実装のポイント

#### 1. セッションの再利用

**重要**: `globalSession`と`session`はインスタンス変数として保持し、初期化時に1回だけ作成します。

```objc
@interface SlangCompiler() {
    slang::IGlobalSession* _globalSession;
    slang::ISession* _session;
}
@end

@implementation SlangCompiler

- (instancetype)init {
    self = [super init];
    if (self) {
        // グローバルセッションとセッションを1回だけ作成
        slang::createGlobalSession(&_globalSession);

        slang::TargetDesc targetDesc = {};
        targetDesc.format = SLANG_METAL;
        targetDesc.profile = _globalSession->findProfile("metal");

        slang::SessionDesc sessionDesc = {};
        sessionDesc.targets = &targetDesc;
        sessionDesc.targetCount = 1;

        _globalSession->createSession(sessionDesc, &_session);
    }
    return self;
}

- (void)dealloc {
    if (_session) _session->release();
    if (_globalSession) _globalSession->release();
}
```

**理由**: 毎回作成/破棄するとアサーション失敗やメモリ破壊が発生します。

#### 2. ユニークなモジュール名

**重要**: 各コンパイルで異なるモジュール名を使用します。

```objc
- (NSString *)compileSlangToMSL:(NSString *)slangSource
                      entryPoint:(NSString *)entryPointName
                           error:(NSError **)error {
    // ユニークなモジュール名を生成
    static int moduleCounter = 0;
    NSString* moduleName = [NSString stringWithFormat:@"shader_%d", ++moduleCounter];

    // モジュールをロード
    slang::IModule* module = _session->loadModuleFromSourceString(
        [moduleName UTF8String],
        [[moduleName stringByAppendingString:@".slang"] UTF8String],
        [slangSource UTF8String]
    );
    // ... 以下省略
}
```

**理由**: 同じモジュール名を使い回すとキャッシュが競合し、2回目以降でエントリーポイントが見つからなくなります。

#### 3. リソース管理

```objc
// エントリーポイントを検索
slang::IEntryPoint* entryPoint = nullptr;
module->findEntryPointByName([entryPointName UTF8String], &entryPoint);

// プログラムを合成
slang::IComponentType* components[] = {module, entryPoint};
slang::IComponentType* composedProgram = nullptr;
_session->createCompositeComponentType(components, 2, &composedProgram);

// MSLコードを取得
slang::IBlob* mslCodeBlob = nullptr;
composedProgram->getEntryPointCode(0, 0, &mslCodeBlob);

NSString* mslSource = [[NSString alloc] initWithBytes:mslCodeBlob->getBufferPointer()
                                               length:mslCodeBlob->getBufferSize()
                                             encoding:NSUTF8StringEncoding];

// 一時リソースのみ解放（sessionとglobalSessionは保持）
mslCodeBlob->release();
composedProgram->release();
entryPoint->release();
module->release();

return mslSource;
```

**重要**: 一時的に作成したSlangオブジェクトは`release()`で解放しますが、`_globalSession`と`_session`は`dealloc`まで保持します。

### Swift使用例

```swift
import SlangCompiler

let compiler = SlangCompiler()

let slangSource = """
[shader("vertex")]
float4 vertexMain(float3 pos : POSITION) : SV_Position {
    return float4(pos, 1.0);
}
"""

do {
    let mslSource = try compiler.compileSlang(toMSL: slangSource,
                                              entryPoint: "vertexMain")
    print("Generated MSL:\n\(mslSource)")
} catch {
    print("Compilation failed: \(error)")
}
```

---

## Swift Package配布

### Package.swift構成

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
            targets: ["SlangCompilerWrapper"]
        ),
    ],
    targets: [
        // Binary XCFramework (GitHub Releasesから取得)
        .binaryTarget(
            name: "SlangCompilerBinary",
            url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v1.0.0/SlangCompiler.xcframework.zip",
            checksum: "YOUR_CHECKSUM_HERE"
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
    ],
    cxxLanguageStandard: .cxx17
)
```

**ポイント**:
- `binaryTarget`でGitHub ReleasesからXCFrameworkをダウンロード
- `SlangCompilerWrapper`でObjective-C++ブリッジをラップ
- `SLANG_DYNAMIC=0`で静的リンクを指定
- `libc++`を明示的にリンク

### GitHub Releasesワークフロー

#### 1. ビルド実行

```bash
make all
```

#### 2. checksumを確認

```bash
cat xcframework/SlangCompiler.xcframework.zip.checksum
```

#### 3. GitHub Releaseを作成

1. GitHubリポジトリページで **Releases** → **Create a new release**
2. タグ: `v1.0.0`
3. タイトル: `v1.0.0 - First Release`
4. 説明: リリースノートを記載
5. バイナリ: `xcframework/SlangCompiler.xcframework.zip`をアップロード
6. **Publish release**

#### 4. Package.swiftを更新

```swift
.binaryTarget(
    name: "SlangCompilerBinary",
    url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v1.0.0/SlangCompiler.xcframework.zip",
    checksum: "上記で確認したchecksum"
),
```

```bash
git add Package.swift
git commit -m "Update Package.swift with v1.0.0 release URL and checksum"
git push origin main
```

### ユーザー側での使用方法

#### Swift Package Managerで追加

`Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/shivaduke28/shader-slang-swift.git", from: "1.0.0")
]
```

#### Xcodeで追加

1. File → Add Packages...
2. URL: `https://github.com/shivaduke28/shader-slang-swift.git`
3. Version: `1.0.0` 〜
4. Add Package

---

## 動作確認とテスト

### シンプルな頂点シェーダー

```slang
[shader("vertex")]
float4 simpleVertex(float3 pos : POSITION) : SV_Position
{
    return float4(pos, 1.0);
}
```

**コンパイル後（MSL）**:
```metal
#include <metal_stdlib>
using namespace metal;

struct vertexOutput_0 {
    float4 output_0 [[position]];
};

struct vertexInput_0 {
    float3 pos_0 [[attribute(0)]];
};

[[vertex]] vertexOutput_0 simpleVertex(vertexInput_0 _S1 [[stage_in]]) {
    vertexOutput_0 _S2 = { float4(_S1.pos_0, 1.0) };
    return _S2;
}
```

### 構造体を使ったシェーダー

```slang
struct VertexInput {
    float3 position : POSITION;
    float2 texCoord : TEXCOORD;
};

struct VertexOutput {
    float4 position : SV_Position;
    float2 texCoord : TEXCOORD;
};

[shader("vertex")]
VertexOutput vertexMain(VertexInput input) {
    VertexOutput output;
    output.position = float4(input.position, 1.0);
    output.texCoord = input.texCoord;
    return output;
}

[shader("fragment")]
float4 fragmentMain(VertexOutput input) : SV_Target {
    return float4(input.texCoord, 0.0, 1.0);
}
```

### Metalでの使用例

```swift
import Metal
import SlangCompiler

let compiler = SlangCompiler()
let slangSource = "..." // 上記シェーダーコード

// Slang → MSLコンパイル
let mslCode = try! compiler.compileSlang(toMSL: slangSource, entryPoint: "fragmentMain")

// Metal library作成
let device = MTLCreateSystemDefaultDevice()!
let library = try! device.makeLibrary(source: mslCode, options: nil)
let function = library.makeFunction(name: "fragmentMain")
```

---

## トラブルシューティング

### ビルドエラー: slang-embed not found

**エラーメッセージ**:
```
ninja: error: '/path/to/slang/generators/bin/slang-embed', needed by ..., missing and no known rule to make it
```

**原因**: generatorsのビルド成果物のパスが間違っている

**解決**:
1. generatorsが正しくビルドされているか確認:
```bash
ls slang/generators/generators/Release/bin/
```

2. Makefileの`SLANG_GENERATORS_PATH`が正しいか確認
3. `make clean && make all`で再ビルド

### ビルドエラー: Ninja not found

**解決**:
```bash
brew install ninja
```

### ビルドエラー: CMake toolchain error

**エラーメッセージ**:
```
-- The C compiler identification is unknown
```

**解決**:
```bash
# Xcodeのパスを確認
xcode-select -p

# 必要に応じて変更
sudo xcode-select -s /Applications/Xcode.app
```

### リンクエラー: Undefined symbols (mz_zip_*, tdefl_*, tinfl_*)

**原因**: minizとlz4の圧縮ライブラリが不足

**解決**: Makefileが自動的に処理します。手動でビルドする場合:
```bash
# miniz, lz4もビルド対象に含める
ninja libslang-compiler.a libcompiler-core.a libcore.a
cp external/miniz/libminiz.a build/ios-device/
cp external/lz4/build/cmake/liblz4.a build/ios-device/
```

### 実行時クラッシュ: EXC_BREAKPOINT (SLANG_ASSERT)

**原因**: セッションを毎回作成/破棄している

**解決**: `SlangCompiler.mm`でセッションをインスタンス変数として保持（上記「Objective-C++ブリッジ」参照）

### コンパイルエラー: "Entry point not found"

**原因**: 同じモジュール名を使い回している

**解決**: ユニークなモジュール名を生成（上記「Objective-C++ブリッジ」参照）

### Swift Package解決エラー

```bash
# キャッシュクリア
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build
```

### checksum不一致

**エラーメッセージ**:
```
checksum of downloaded artifact does not match checksum specified
```

**解決**:
```bash
# checksumを再計算
swift package compute-checksum xcframework/SlangCompiler.xcframework.zip

# Package.swiftを更新してコミット
```

---

## 参考資料

### Slang公式

- [Slang公式サイト](https://shader-slang.org/)
- [Slangドキュメント](https://shader-slang.org/docs/getting-started/)
- [Slang GitHubリポジトリ](https://github.com/shader-slang/slang)
- [Slangビルド手順](https://github.com/shader-slang/slang/blob/master/docs/building.md)

### Apple開発者向け

- [Apple XCFramework Documentation](https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle)
- [Swift Package Manager Documentation](https://www.swift.org/package-manager/)
- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)

### 参考にしたサンプル

- [hello-world example](https://github.com/shader-slang/slang/tree/master/examples/hello-world) - C++ APIの基本的な使い方

### 関連Issue

- [Issue #2121: Why not support Android iOS and Mac](https://github.com/shader-slang/slang/issues/2121) - モバイルサポートの議論

---

## 重要なハマりどころまとめ

### 1. Metalバックエンドのサポート状況

- **2022年時点**: SlangはMetalバックエンドを持っていなかった
- **現在（2025年）**: Metalサポートが追加されている
  - ターゲット: `SLANG_METAL` (MSLソースコード生成)
  - サポート状況: 部分的だが、基本的なシェーダーは動作可能

### 2. iOS向けビルドの制約

- **公式サポートなし**: Slangは公式にはiOS/Androidをサポートしていない
- **動的ライブラリ不可**: iOSでは任意の`.dylib`をロードできないため、静的ライブラリ（`.a`）が必須
- **ビルドオプションの調整**: 多くのターゲット（slangc、slangi、gfx等）を無効化する必要がある

### 3. クロスコンパイルの必要性

- Slangはビルド時にコード生成ツール（generators）を実行する
- iOS向けビルドでは、macOS用のgeneratorsを先にビルドして使用する必要がある
- `SLANG_GENERATORS_PATH`で事前ビルドしたgeneratorsを指定

### 4. ライブラリサイズ最適化

- ビルド直後: **1.0GB** (デバッグシンボル含む)
- `strip -S`後: **31MB** (**97%削減**)
- **必須**: 本番環境ではstrip版を使用すること

### 5. セッション管理

- ❌ 毎回作成/破棄: クラッシュの原因
- ✅ インスタンス変数として保持: 安全

### 6. モジュール名

- ❌ 同じ名前を使い回す: キャッシュ競合でエラー
- ✅ ユニークな名前を生成: 正常動作

### 7. LLVMサポート

- iOS向けビルドでは、prebuiltのLLVMバイナリが利用不可
- 警告が出るが、基本的なMetal出力には影響なし
- 必要に応じて、LLVMを手動でビルドして統合可能

---

## ライセンス

このプロジェクトは**Apache 2.0 with LLVM exception**ライセンスです（Slangと同じ）。

詳細は[slang/LICENSE](../slang/LICENSE)を参照してください。

---

## 作業履歴

- **2025-11-02**: shader-slang-swiftプロジェクト開始
  - 午前: Slang submodule追加、toolchain作成
  - 午後: Makefile作成、ライブラリマージ実装
  - 夕方: Objective-C++ブリッジ実装
  - 夜: Package.swift作成、ドキュメント統合

---

このドキュメントは、`docs/SLANG.md`（Arshesプロジェクトでの実験記録）と`docs/SLANG_PKG.md`（旧ビルドガイド）を統合・更新したものです。
