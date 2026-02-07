.PHONY: help setup-voicevox clean-voicevox

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup-voicevox: ## Download VOICEVOX resources from S3 and setup for iOS development
	@echo "📥 Downloading VOICEVOX resources from S3..."
	@aws s3 sync s3://zuntalk-resources/ libs/ \
		--exclude ".DS_Store" \
		--exclude "*/.DS_Store"
	@echo "✅ Download complete"
	@echo ""
	@echo "🔧 Setting up iOS project..."
	@rm -rf ios/Voicevox/voicevox_core.xcframework
	@rm -rf ios/Voicevox/voicevox_onnxruntime.xcframework
	@rsync -a libs/voicevox_core/voicevox_core-0.16.3/voicevox_core.xcframework ios/Voicevox/
	@rsync -a libs/voicevox_onnxruntime-ios-xcframework/voicevox_onnxruntime-ios-xcframework-1.17.3/voicevox_onnxruntime.xcframework ios/Voicevox/
	@rsync -a libs/voicevox_core/voicevox_core-0.16.3/dict/open_jtalk_dic_utf_8-1.11 ios/ZunTalk/
	@mkdir -p ios/ZunTalk/vvms
	@cp libs/voicevox_core/voicevox_core-0.16.3/models/vvms/*.vvm ios/ZunTalk/vvms/
	@echo "✅ iOS project setup complete"
	@echo ""
	@echo "🎉 VOICEVOX resources are ready! You can now open the Xcode project."

clean-voicevox: ## Remove downloaded VOICEVOX resources
	@echo "🧹 Cleaning VOICEVOX resources..."
	@rm -rf libs/
	@echo "✅ Clean complete"
