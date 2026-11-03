CARGO ?= cargo
# The sibling core repo. `.cargo/config.toml` forwards `cargo xtask` to the same
# path; change both together if the checkout layout ever changes.
CORE_DIR ?= $(CURDIR)/../flare-core-sdk-engine
# Single source of truth for built native artifacts: the core repo's dist/ folder.
# Populate it from the core repo with:  cd $(CORE_DIR) && make dist
CORE_DIST ?= $(CORE_DIR)/dist
EXAMPLES_DIR ?= examples
PACKAGES_DIR ?= packages

FFI_A := libflare_im_core_sdk_ffi.a
FFI_SO := libflare_im_core_sdk_ffi.so
FFI_DYLIB := libflare_im_core_sdk_ffi.dylib
ANDROID_ABIS ?= arm64-v8a armeabi-v7a x86_64
IOS_TRIPLES ?= aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
# Every jniLibs root that consumes the Android FFI .so (app + SDK package + flutter app).
ANDROID_JNI_ROOTS := \
	$(EXAMPLES_DIR)/flare-core-android-app/app/src/main/jniLibs \
	$(PACKAGES_DIR)/flare-core-android-sdk/src/main/jniLibs \
	$(EXAMPLES_DIR)/flare-core-flutter-app/android/app/src/main/jniLibs

.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf '%s\n' 'Sync core-sdk artifacts (from $(CORE_DIST)) into each platform location:'
	@printf '  %-20s %s\n' 'make sync' 'android + ios + flutter (one command)'
	@printf '  %-20s %s\n' 'make sync-android' 'dist/android/<abi>/*.so -> app + SDK + flutter jniLibs'
	@printf '  %-20s %s\n' 'make sync-ios' 'dist/{host,ios} -> examples/flare-core-ios-app/FFI'
	@printf '  %-20s %s\n' 'make sync-flutter' 'dist/{host,ios} -> flutter macOS dylib + iOS universal .a'
	@printf '%s\n' '(tauri/web wasm: the bundler resolves it from flare-core-sdk-engine/bindings/wasm/pkg; no copy needed)'

.PHONY: sync
sync: sync-android sync-ios sync-flutter ## Distribute core dist/ into all native platform locations
	@echo "synced $(CORE_DIST) -> android + ios + flutter"

.PHONY: sync-android
sync-android:
	@for abi in $(ANDROID_ABIS); do \
		src="$(CORE_DIST)/android/$$abi/$(FFI_SO)"; \
		if [ ! -f "$$src" ]; then echo "skip android $$abi (missing $$src)"; continue; fi; \
		for root in $(ANDROID_JNI_ROOTS); do \
			mkdir -p "$$root/$$abi"; cp -f "$$src" "$$root/$$abi/$(FFI_SO)"; \
		done; \
		echo "android $$abi -> jniLibs"; \
	done

.PHONY: sync-ios
sync-ios:
	@dest="$(EXAMPLES_DIR)/flare-core-ios-app/FFI"; mkdir -p "$$dest"; \
	if [ -f "$(CORE_DIST)/host/$(FFI_DYLIB)" ]; then cp -f "$(CORE_DIST)/host/$(FFI_DYLIB)" "$$dest/"; echo "ios host dylib"; fi; \
	for t in $(IOS_TRIPLES); do \
		src="$(CORE_DIST)/ios/$$t/$(FFI_A)"; \
		if [ -f "$$src" ]; then mkdir -p "$$dest/ios/$$t"; cp -f "$$src" "$$dest/ios/$$t/"; echo "ios $$t"; fi; \
	done; \
	if [ -f "$(CORE_DIST)/include/flare_im_core_sdk_ffi.h" ]; then cp -f "$(CORE_DIST)/include/flare_im_core_sdk_ffi.h" "$$dest/"; fi

.PHONY: sync-flutter
sync-flutter:
	@if [ -f "$(CORE_DIST)/host/$(FFI_DYLIB)" ]; then \
		mkdir -p "$(EXAMPLES_DIR)/flare-core-flutter-app/macos/Runner"; \
		cp -f "$(CORE_DIST)/host/$(FFI_DYLIB)" "$(EXAMPLES_DIR)/flare-core-flutter-app/macos/Runner/"; \
		echo "flutter macos dylib"; \
	fi
	@sim="$(CORE_DIST)/ios/aarch64-apple-ios-sim/$(FFI_A)"; \
	x86="$(CORE_DIST)/ios/x86_64-apple-ios/$(FFI_A)"; \
	dest="$(EXAMPLES_DIR)/flare-core-flutter-app/ios/FFI/build"; \
	if [ -f "$$sim" ]; then \
		mkdir -p "$$dest"; \
		if [ -f "$$x86" ]; then lipo -create "$$sim" "$$x86" -output "$$dest/$(FFI_A)"; else cp -f "$$sim" "$$dest/$(FFI_A)"; fi; \
		echo "flutter ios universal"; \
	fi

# Forward any other target to xtask (kept from the previous Makefile).
%:
	@$(CARGO) xtask $@

check-wire: ## 跨端校验 wire 编码器与模型类型一致（防契约漂移只改一端）
	node scripts/check-wire-encoder-consistency.mjs

.PHONY: reference-app-public-api-check reference-app-no-duplicate-ui-check reference-app-style-ownership-check reference-app-ui-check
reference-app-public-api-check:
	node scripts/reference-app-public-api-check.mjs
reference-app-no-duplicate-ui-check:
	node scripts/reference-app-no-duplicate-ui-check.mjs
reference-app-style-ownership-check:
	node scripts/reference-app-style-ownership-check.mjs
reference-app-ui-check: reference-app-public-api-check reference-app-no-duplicate-ui-check reference-app-style-ownership-check
