//
//  SlangCompiler.h
//  SlangTest
//
//  Objective-C bridge for Slang Shader Language Compiler
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper for Slang shader compiler
@interface SlangCompiler : NSObject

/// Compiles Slang shader source code to Metal Shading Language (MSL)
/// @param slangSource The Slang shader source code
/// @param entryPointName The entry point function name (e.g., "main", "vertexMain")
/// @param error Output parameter for error information
/// @return The compiled MSL source code, or nil if compilation failed
- (nullable NSString *)compileSlangToMSL:(NSString *)slangSource
                              entryPoint:(NSString *)entryPointName
                                   error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
