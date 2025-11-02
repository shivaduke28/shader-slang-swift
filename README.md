# SlangCompiler for iOS

[Slang](https://github.com/shader-slang/slang) Compiler for iOS.

## Requirements

- iOS 17.0+
- Xcode 15.0+
- arm64

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

## License

Apache 2.0 with LLVM exception (same as Slang)
See [LICENSE](LICENSE) for details.
