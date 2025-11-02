# SlangCompiler for iOS

[Slang](https://github.com/shader-slang/slang) Shader Language Compiler for iOS - Swift Package

## Overview

This package provides the Slang shader compiler for iOS applications. Slang is a shading language that compiles to multiple targets including **Metal Shading Language (MSL)**, enabling you to write shaders once and compile them at runtime for Metal.

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/shivaduke28/shader-slang-swift.git", from: "1.0.0")
]
```

Or via Xcode:
1. File → Add Packages...
2. Enter: `https://github.com/shivaduke28/shader-slang-swift.git`
3. Select version and add to your target

## Usage

### Basic Example

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

### Compiling to Metal

The compiled MSL code can be used directly with Metal:

```swift
import Metal

let compiler = SlangCompiler()

// Your Slang shader source
let slangSource = """
[shader("fragment")]
float4 fragmentMain(float4 color : COLOR) : SV_Target
{
    return color;
}
"""

// Compile to MSL
let mslCode = try! compiler.compileSlang(toMSL: slangSource, entryPoint: "fragmentMain")

// Create Metal library from MSL
let device = MTLCreateSystemDefaultDevice()!
let library = try! device.makeLibrary(source: mslCode, options: nil)
let function = library.makeFunction(name: "fragmentMain")
```

## Requirements

- iOS 17.0+
- Xcode 15.0+

## Supported Platforms

| Platform | Architecture | Status |
|----------|--------------|--------|
| iOS Device | arm64 | ✅ Supported |
| iOS Simulator (Apple Silicon) | arm64 | ✅ Supported |
| iOS Simulator (Intel) | x86_64 | ❌ Not supported |

---

## For Developers: Building from Source

This section is for developers who want to build the XCFramework from source.

### Prerequisites

- macOS with Xcode 15.0+
- Command Line Tools: `xcode-select --install`
- CMake and Ninja: `brew install cmake ninja`

### Repository Structure

```
shader-slang-swift/
├── Package.swift          # Swift Package definition
├── Makefile               # Build automation
├── Sources/
│   └── SlangCompiler/     # Objective-C++ bridge
├── slang/                 # Slang submodule (official repo)
├── toolchains/            # CMake toolchain files
├── build/                 # Build artifacts (gitignored)
└── xcframework/           # XCFrameworks (gitignored)
```

### Building

#### Quick Start

Build everything and create distribution archive:

```bash
# Clone with submodules
git clone --recursive https://github.com/shivaduke28/shader-slang-swift.git
cd shader-slang-swift

# Build all
make all
```

This will:
1. Build code generators (host)
2. Build for iOS Device (arm64)
3. Build for iOS Simulator (arm64)
4. Merge all libraries into one
5. Create XCFramework
6. Create distribution archive with checksum

#### Build Targets

```bash
# Build generators only (first time only)
make generators

# Build for specific platform
make device       # iOS Device (arm64)
make simulator    # iOS Simulator (arm64)

# Build all platforms
make build

# Create XCFramework from existing builds
make xcframework

# Create distribution archive
make archive

# Verify build artifacts
make verify

# Clean all build artifacts
make clean

# Show help
make help
```

### Build Output

- `build/ios-device/libSlangCompiler.a` - Merged iOS Device library
- `build/ios-simulator-arm64/libSlangCompiler.a` - Merged iOS Simulator library
- `xcframework/SlangCompiler.xcframework` - Final XCFramework
- `xcframework/SlangCompiler.xcframework.zip` - Distribution archive
- `xcframework/SlangCompiler.xcframework.zip.checksum` - SHA256 checksum

### Build Time

- **Generators**: ~2-5 minutes (first time only)
- **iOS Device**: ~5-15 minutes
- **iOS Simulator**: ~5-15 minutes
- **Total**: ~10-30 minutes (depending on hardware)

### Distribution Workflow

1. Build the XCFramework:
   ```bash
   make all
   ```

2. Create a new GitHub Release (e.g., `v1.0.0`)

3. Upload `xcframework/SlangCompiler.xcframework.zip` to the release

4. Update `Package.swift` with the release URL and checksum:
   ```swift
   .binaryTarget(
       name: "SlangCompilerBinary",
       url: "https://github.com/shivaduke28/shader-slang-swift/releases/download/v1.0.0/SlangCompiler.xcframework.zip",
       checksum: "YOUR_CHECKSUM_HERE"  // From .checksum file
   ),
   ```

5. Commit and tag:
   ```bash
   git add Package.swift
   git commit -m "Release v1.0.0"
   git tag v1.0.0
   git push origin main --tags
   ```

## License

Apache 2.0 with LLVM exception (same as Slang)

See [slang/LICENSE](slang/LICENSE) for details.

## Credits

This package wraps the [Slang shader compiler](https://github.com/shader-slang/slang) developed by NVIDIA and contributors.

## Links

- [Slang Official Repository](https://github.com/shader-slang/slang)
- [Slang Documentation](https://shader-slang.org/)
- [Swift Package Manager Documentation](https://www.swift.org/package-manager/)
