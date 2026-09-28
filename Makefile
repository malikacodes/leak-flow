PROJECT = LeakFlow.xcodeproj
SCHEME = LeakFlow
CONFIG = Release
BUILD_DIR = build
DERIVED_DATA = $(BUILD_DIR)/DerivedData
APP_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIG)/LeakFlow.app
ZIP_PATH = $(BUILD_DIR)/LeakFlow.zip

.PHONY: build zip clean test-quarantine

build:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		ARCHS=arm64 \
		ONLY_ACTIVE_ARCH=NO \
		CODE_SIGN_IDENTITY="-" \
		DEVELOPMENT_TEAM="" \
		ENABLE_HARDENED_RUNTIME=NO

zip: build
	ditto -c -k --keepParent "$(APP_PATH)" "$(ZIP_PATH)"
	@echo "Created $(ZIP_PATH)"

test-quarantine: zip
	rm -rf /tmp/LeakFlowTest
	mkdir -p /tmp/LeakFlowTest
	ditto -x -k "$(ZIP_PATH)" /tmp/LeakFlowTest
	xattr -w com.apple.quarantine "0081;$(shell printf '%x' $$(date +%s));Safari;00000000-0000-0000-0000-000000000000" /tmp/LeakFlowTest/LeakFlow.app
	@echo ""
	@echo "=== Quarantined app ready ==="
	@echo "To test mic permission from scratch:"
	@echo "  tccutil reset Microphone com.malikapixels.leakflow"
	@echo "  open /tmp/LeakFlowTest/LeakFlow.app"
	@echo ""
	@echo "Verify no hardened runtime:"
	@echo "  codesign -dvvv /tmp/LeakFlowTest/LeakFlow.app"
	@echo ""

clean:
	rm -rf $(BUILD_DIR)
