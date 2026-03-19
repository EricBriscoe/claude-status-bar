.PHONY: build app run install zip clean

APP_BUNDLE = ClaudeStatus.app

build:
	swift build -c release --arch arm64 --arch x86_64

app: build
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@cp "$$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClaudeStatusBar" "$(APP_BUNDLE)/Contents/MacOS/"
	@cp Info.plist "$(APP_BUNDLE)/Contents/"
	@echo "Built $(APP_BUNDLE)"

run: app
	@open "$(APP_BUNDLE)"

install: app
	@cp -r "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

zip: app
	@zip -r ClaudeStatus.zip "$(APP_BUNDLE)"
	@echo "Created ClaudeStatus.zip"

clean:
	swift package clean
	@rm -rf "$(APP_BUNDLE)" ClaudeStatus.zip
