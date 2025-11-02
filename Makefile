# Slang iOS Build Makefile

# Directories
PROJECT_ROOT := $(shell pwd)
SLANG_DIR := $(PROJECT_ROOT)/slang
BUILD_DIR := $(PROJECT_ROOT)/build
XCFRAMEWORK_DIR := $(PROJECT_ROOT)/xcframework
TOOLCHAINS_DIR := $(PROJECT_ROOT)/toolchains

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

# Build configuration
CMAKE_BUILD_TYPE := Release
NINJA := ninja

# Archive name
ARCHIVE_NAME := SlangCompiler.xcframework.zip

.PHONY: help all generators device simulator build xcframework archive clean verify

help:
	@echo "$(GREEN)Slang iOS Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)generators$(NC)   - Build code generators (host)"
	@echo "  $(YELLOW)device$(NC)       - Build for iOS Device (arm64)"
	@echo "  $(YELLOW)simulator$(NC)    - Build for iOS Simulator (arm64)"
	@echo "  $(YELLOW)build$(NC)        - Build all platforms"
	@echo "  $(YELLOW)xcframework$(NC)  - Create XCFrameworks"
	@echo "  $(YELLOW)archive$(NC)      - Create distribution archive"
	@echo "  $(YELLOW)all$(NC)          - Build everything and create archive"
	@echo "  $(YELLOW)verify$(NC)       - Verify build artifacts"
	@echo "  $(YELLOW)clean$(NC)        - Clean all build artifacts"
	@echo ""
	@echo "Examples:"
	@echo "  make all          # Build everything"
	@echo "  make device       # Build only iOS Device"
	@echo "  make xcframework  # Create XCFrameworks from existing builds"

all: build xcframework archive

# Build generators (host environment)
generators:
	@echo "$(YELLOW)[1/3] Building generators (host)...$(NC)"
	@if [ -d "$(SLANG_DIR)/generators/bin" ]; then \
		echo "Generators already built. Skipping..."; \
	else \
		cd $(SLANG_DIR) && \
		mkdir -p generators && \
		cd generators && \
		cmake .. \
			-G Ninja \
			-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
			-DSLANG_ENABLE_TESTS=OFF \
			-DSLANG_ENABLE_EXAMPLES=OFF \
			-DSLANG_ENABLE_GFX=OFF && \
		$(NINJA); \
	fi
	@echo "$(GREEN)✓ Generators ready$(NC)"

# Build for iOS Device
device: generators
	@echo "$(YELLOW)[2/3] Building for iOS Device (arm64)...$(NC)"
	@cd $(SLANG_DIR) && \
	rm -rf build-ios-device && \
	mkdir -p build-ios-device && \
	cd build-ios-device && \
	cmake .. \
		-G Ninja \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAINS_DIR)/ios-device.toolchain.cmake \
		-DSLANG_GENERATORS_PATH=$(SLANG_DIR)/generators/generators/Release/bin \
		-DSLANG_LIB_TYPE=STATIC \
		-DSLANG_ENABLE_TESTS=OFF \
		-DSLANG_ENABLE_EXAMPLES=OFF \
		-DSLANG_ENABLE_GFX=OFF \
		-DSLANG_ENABLE_SLANGD=OFF \
		-DSLANG_ENABLE_SLANGC=OFF \
		-DSLANG_ENABLE_SLANGRT=OFF \
		-DSLANG_ENABLE_SLANGI=OFF && \
	$(NINJA) libslang-compiler.a libcompiler-core.a libcore.a && \
	cd Release/lib && \
	strip -S libslang-compiler.a && \
	strip -S libcompiler-core.a && \
	strip -S libcore.a && \
	strip -S ../../external/miniz/libminiz.a && \
	strip -S ../../external/lz4/build/cmake/liblz4.a
	@mkdir -p $(BUILD_DIR)/ios-device
	@cp $(SLANG_DIR)/build-ios-device/Release/lib/*.a $(BUILD_DIR)/ios-device/
	@cp $(SLANG_DIR)/build-ios-device/external/miniz/libminiz.a $(BUILD_DIR)/ios-device/
	@cp $(SLANG_DIR)/build-ios-device/external/lz4/build/cmake/liblz4.a $(BUILD_DIR)/ios-device/
	@echo "$(YELLOW)Merging libraries into single archive...$(NC)"
	@cd $(BUILD_DIR)/ios-device && \
	libtool -static -o libSlangCompiler.a \
		libslang-compiler.a \
		libcompiler-core.a \
		libcore.a \
		libminiz.a \
		liblz4.a
	@echo "$(GREEN)✓ iOS Device build complete$(NC)"

# Build for iOS Simulator
simulator: generators
	@echo "$(YELLOW)[3/3] Building for iOS Simulator (arm64)...$(NC)"
	@cd $(SLANG_DIR) && \
	rm -rf build-ios-simulator-arm64 && \
	mkdir -p build-ios-simulator-arm64 && \
	cd build-ios-simulator-arm64 && \
	cmake .. \
		-G Ninja \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DCMAKE_TOOLCHAIN_FILE=$(TOOLCHAINS_DIR)/ios-simulator-arm64.toolchain.cmake \
		-DSLANG_GENERATORS_PATH=$(SLANG_DIR)/generators/generators/Release/bin \
		-DSLANG_LIB_TYPE=STATIC \
		-DSLANG_ENABLE_TESTS=OFF \
		-DSLANG_ENABLE_EXAMPLES=OFF \
		-DSLANG_ENABLE_GFX=OFF \
		-DSLANG_ENABLE_SLANGD=OFF \
		-DSLANG_ENABLE_SLANGC=OFF \
		-DSLANG_ENABLE_SLANGRT=OFF \
		-DSLANG_ENABLE_SLANGI=OFF && \
	$(NINJA) libslang-compiler.a libcompiler-core.a libcore.a && \
	cd Release/lib && \
	strip -S libslang-compiler.a && \
	strip -S libcompiler-core.a && \
	strip -S libcore.a && \
	strip -S ../../external/miniz/libminiz.a && \
	strip -S ../../external/lz4/build/cmake/liblz4.a
	@mkdir -p $(BUILD_DIR)/ios-simulator-arm64
	@cp $(SLANG_DIR)/build-ios-simulator-arm64/Release/lib/*.a $(BUILD_DIR)/ios-simulator-arm64/
	@cp $(SLANG_DIR)/build-ios-simulator-arm64/external/miniz/libminiz.a $(BUILD_DIR)/ios-simulator-arm64/
	@cp $(SLANG_DIR)/build-ios-simulator-arm64/external/lz4/build/cmake/liblz4.a $(BUILD_DIR)/ios-simulator-arm64/
	@echo "$(YELLOW)Merging libraries into single archive...$(NC)"
	@cd $(BUILD_DIR)/ios-simulator-arm64 && \
	libtool -static -o libSlangCompiler.a \
		libslang-compiler.a \
		libcompiler-core.a \
		libcore.a \
		libminiz.a \
		liblz4.a
	@echo "$(GREEN)✓ iOS Simulator build complete$(NC)"

# Build all platforms
build: device simulator
	@echo "$(GREEN)✓ All platforms built successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)Build artifact sizes:$(NC)"
	@du -h $(BUILD_DIR)/*/*.a | sort

# Create XCFramework
xcframework:
	@echo "$(YELLOW)Creating XCFramework...$(NC)"
	@if [ ! -d "$(BUILD_DIR)/ios-device" ] || [ ! -d "$(BUILD_DIR)/ios-simulator-arm64" ]; then \
		echo "$(RED)Error: Build artifacts not found. Run 'make build' first.$(NC)"; \
		exit 1; \
	fi
	@rm -rf $(XCFRAMEWORK_DIR)
	@mkdir -p $(XCFRAMEWORK_DIR)
	@echo "  - SlangCompiler.xcframework (merged library)"
	@xcodebuild -create-xcframework \
		-library $(BUILD_DIR)/ios-device/libSlangCompiler.a \
		-library $(BUILD_DIR)/ios-simulator-arm64/libSlangCompiler.a \
		-output $(XCFRAMEWORK_DIR)/SlangCompiler.xcframework > /dev/null
	@echo "$(GREEN)✓ XCFramework created$(NC)"

# Create distribution archive
archive: xcframework
	@echo "$(YELLOW)Creating distribution archive...$(NC)"
	@cd $(XCFRAMEWORK_DIR) && \
	rm -f $(ARCHIVE_NAME) && \
	zip -r $(ARCHIVE_NAME) SlangCompiler.xcframework > /dev/null
	@echo "$(GREEN)✓ Archive created: $(ARCHIVE_NAME)$(NC)"
	@echo ""
	@echo "$(YELLOW)Computing checksum...$(NC)"
	@cd $(XCFRAMEWORK_DIR) && \
	swift package compute-checksum $(ARCHIVE_NAME) > $(ARCHIVE_NAME).checksum
	@echo "$(GREEN)✓ Checksum: $$(cat $(XCFRAMEWORK_DIR)/$(ARCHIVE_NAME).checksum)$(NC)"
	@echo ""
	@echo "$(YELLOW)Distribution archive:$(NC)"
	@echo "  Location: $(XCFRAMEWORK_DIR)/$(ARCHIVE_NAME)"
	@echo "  Size: $$(cd $(XCFRAMEWORK_DIR) && du -h $(ARCHIVE_NAME) | cut -f1)"
	@echo "  Checksum: $$(cat $(XCFRAMEWORK_DIR)/$(ARCHIVE_NAME).checksum)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Create a new release on GitHub (e.g., v1.0.0)"
	@echo "  2. Upload $(ARCHIVE_NAME) to the release"
	@echo "  3. Update Package.swift with the release URL and checksum above"

# Verify build artifacts
verify:
	@echo "$(YELLOW)Verifying build artifacts...$(NC)"
	@if [ -f "$(BUILD_DIR)/ios-device/libSlangCompiler.a" ]; then \
		echo "$(GREEN)✓ iOS Device merged library:$(NC)"; \
		ls -lh $(BUILD_DIR)/ios-device/libSlangCompiler.a; \
		lipo -info $(BUILD_DIR)/ios-device/libSlangCompiler.a; \
	else \
		echo "$(RED)✗ iOS Device library not found$(NC)"; \
	fi
	@echo ""
	@if [ -f "$(BUILD_DIR)/ios-simulator-arm64/libSlangCompiler.a" ]; then \
		echo "$(GREEN)✓ iOS Simulator merged library:$(NC)"; \
		ls -lh $(BUILD_DIR)/ios-simulator-arm64/libSlangCompiler.a; \
		lipo -info $(BUILD_DIR)/ios-simulator-arm64/libSlangCompiler.a; \
	else \
		echo "$(RED)✗ iOS Simulator library not found$(NC)"; \
	fi
	@echo ""
	@if [ -d "$(XCFRAMEWORK_DIR)/SlangCompiler.xcframework" ]; then \
		echo "$(GREEN)✓ XCFramework:$(NC)"; \
		find $(XCFRAMEWORK_DIR)/SlangCompiler.xcframework -name "*.a" -exec echo "  " {} \; -exec lipo -info {} \;; \
	else \
		echo "$(RED)✗ XCFramework not found$(NC)"; \
	fi

# Clean all build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(SLANG_DIR)/build-ios-device
	@rm -rf $(SLANG_DIR)/build-ios-simulator-arm64
	@rm -rf $(SLANG_DIR)/generators
	@rm -rf $(BUILD_DIR)
	@rm -rf $(XCFRAMEWORK_DIR)
	@echo "$(GREEN)✓ Clean complete$(NC)"
