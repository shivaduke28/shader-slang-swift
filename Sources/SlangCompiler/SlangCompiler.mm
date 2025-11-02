//
//  SlangCompiler.mm
//  SlangTest
//
//  Objective-C++ bridge implementation for Slang Shader Language Compiler
//

#import "SlangCompiler.h"
#include "slang.h"

// Error domain for Slang compilation errors
static NSString * const SlangCompilerErrorDomain = @"com.slangtest.SlangCompiler";

typedef NS_ENUM(NSInteger, SlangCompilerErrorCode) {
    SlangCompilerErrorCodeGlobalSessionCreationFailed = 1,
    SlangCompilerErrorCodeSessionCreationFailed,
    SlangCompilerErrorCodeModuleLoadFailed,
    SlangCompilerErrorCodeEntryPointNotFound,
    SlangCompilerErrorCodeProgramCompositionFailed,
    SlangCompilerErrorCodeCodeGenerationFailed,
};

@interface SlangCompiler() {
    slang::IGlobalSession* _globalSession;
    slang::ISession* _session;
}
@end

@implementation SlangCompiler

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Create global session once
        if (SLANG_FAILED(slang::createGlobalSession(&_globalSession))) {
            return nil;
        }

        // Setup Metal target
        slang::TargetDesc targetDesc = {};
        targetDesc.format = SLANG_METAL;
        targetDesc.profile = _globalSession->findProfile("metal");

        // Create session once
        slang::SessionDesc sessionDesc = {};
        sessionDesc.targets = &targetDesc;
        sessionDesc.targetCount = 1;

        if (SLANG_FAILED(_globalSession->createSession(sessionDesc, &_session))) {
            _globalSession->release();
            _globalSession = nullptr;
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    // Clean up Slang resources
    if (_session) {
        _session->release();
        _session = nullptr;
    }
    if (_globalSession) {
        _globalSession->release();
        _globalSession = nullptr;
    }
}

- (nullable NSString *)compileSlangToMSL:(NSString *)slangSource
                              entryPoint:(NSString *)entryPointName
                                   error:(NSError **)error
{
    // Check if session is initialized
    if (!_session || !_globalSession) {
        if (error) {
            *error = [NSError errorWithDomain:SlangCompilerErrorDomain
                                         code:SlangCompilerErrorCodeSessionCreationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Slang session not initialized"}];
        }
        return nil;
    }

    // 1. Load module from source string
    // Generate unique module name to avoid caching issues
    static int moduleCounter = 0;
    NSString* moduleName = [NSString stringWithFormat:@"shader_%d", ++moduleCounter];
    NSString* moduleFileName = [NSString stringWithFormat:@"%@.slang", moduleName];

    const char* slangSourceCStr = [slangSource UTF8String];
    const char* moduleNameCStr = [moduleName UTF8String];
    const char* moduleFileNameCStr = [moduleFileName UTF8String];

    slang::IModule* module = _session->loadModuleFromSourceString(
        moduleNameCStr,
        moduleFileNameCStr,
        slangSourceCStr
    );

    if (!module) {
        if (error) {
            *error = [NSError errorWithDomain:SlangCompilerErrorDomain
                                         code:SlangCompilerErrorCodeModuleLoadFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to load Slang module from source"}];
        }
        return nil;
    }

    // 2. Find entry point
    const char* entryPointCStr = [entryPointName UTF8String];
    slang::IEntryPoint* entryPoint = nullptr;
    if (SLANG_FAILED(module->findEntryPointByName(entryPointCStr, &entryPoint))) {
        module->release();
        if (error) {
            NSString* message = [NSString stringWithFormat:@"Entry point '%@' not found in shader", entryPointName];
            *error = [NSError errorWithDomain:SlangCompilerErrorDomain
                                         code:SlangCompilerErrorCodeEntryPointNotFound
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    // 3. Compose program
    slang::IComponentType* components[] = {module, entryPoint};
    slang::IComponentType* composedProgram = nullptr;
    if (SLANG_FAILED(_session->createCompositeComponentType(components, 2, &composedProgram))) {
        entryPoint->release();
        module->release();
        if (error) {
            *error = [NSError errorWithDomain:SlangCompilerErrorDomain
                                         code:SlangCompilerErrorCodeProgramCompositionFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to compose shader program"}];
        }
        return nil;
    }

    // 4. Get MSL code
    slang::IBlob* mslCodeBlob = nullptr;
    if (SLANG_FAILED(composedProgram->getEntryPointCode(0, 0, &mslCodeBlob))) {
        composedProgram->release();
        entryPoint->release();
        module->release();
        if (error) {
            *error = [NSError errorWithDomain:SlangCompilerErrorDomain
                                         code:SlangCompilerErrorCodeCodeGenerationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"Failed to generate MSL code"}];
        }
        return nil;
    }

    // 5. Convert to NSString
    const char* mslSourceCStr = (const char*)mslCodeBlob->getBufferPointer();
    size_t mslSourceLength = mslCodeBlob->getBufferSize();
    NSString* mslSource = [[NSString alloc] initWithBytes:mslSourceCStr
                                                   length:mslSourceLength
                                                 encoding:NSUTF8StringEncoding];

    // 6. Clean up temporary resources (but keep session and globalSession alive)
    mslCodeBlob->release();
    composedProgram->release();
    entryPoint->release();
    module->release();

    return mslSource;
}

@end
