.PHONY: build install run clean help

APP_NAME = Activity Tracker
INSTALL_DIR = /Applications

help:
	@echo "Usage:"
	@echo "  make build    - Build .app bundle"
	@echo "  make install  - Build and install to /Applications"
	@echo "  make run      - Build, install, and launch"
	@echo "  make clean    - Remove build artifacts"

build:
	@./build-app.sh

install: build
	@echo "📲 Installing to $(INSTALL_DIR)..."
	@rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@cp -r "$(APP_NAME).app" "$(INSTALL_DIR)/"
	@echo "✅ Installed!"

run: install
	@echo "🚀 Launching..."
	@open "$(INSTALL_DIR)/$(APP_NAME).app"

clean:
	@echo "🧹 Cleaning..."
	@rm -rf .build
	@rm -rf "$(APP_NAME).app"
	@echo "✅ Clean!"
