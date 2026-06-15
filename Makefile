BUILD_DIR := build
PREFIX ?= $(HOME)/.local
APP_DIR ?= $(HOME)/Applications
VERSION := 0.0.3

CLIENT := $(BUILD_DIR)/finder-go-up-client
APP_BIN := $(BUILD_DIR)/finder-go-up
APP := $(BUILD_DIR)/finder-go-up.app

CFLAGS := -framework Foundation -O2 -Wall -Wextra
APP_CFLAGS := -framework Cocoa -framework Foundation -O2 -Wall -Wextra

.PHONY: all clean install uninstall package

all: $(CLIENT) $(APP_BIN) app

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(CLIENT): src/client.m src/navigate.m src/common.h src/navigate.h | $(BUILD_DIR)
	clang $(CFLAGS) -o $@ src/client.m src/navigate.m

$(APP_BIN): src/app.m src/navigate.m src/updater.m src/common.h src/navigate.h src/updater.h | $(BUILD_DIR)
	clang $(APP_CFLAGS) -o $@ src/app.m src/navigate.m src/updater.m

app: $(APP_BIN) resources/AppIcon.icns
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	sed 's/@@VERSION@@/$(VERSION)/g' resources/Info.plist > "$(APP)/Contents/Info.plist"
	cp resources/PkgInfo "$(APP)/Contents/PkgInfo"
	cp resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp "$(APP_BIN)" "$(APP)/Contents/MacOS/finder-go-up"
	cp "$(CLIENT)" "$(APP)/Contents/MacOS/finder-go-up-client"
	cp scripts/set-service-shortcut.sh "$(APP)/Contents/Resources/"
	cp scripts/register-background-agent.sh "$(APP)/Contents/Resources/"
	chmod +x "$(APP)/Contents/MacOS/finder-go-up" "$(APP)/Contents/MacOS/finder-go-up-client"
	bash scripts/sign-app.sh "$(APP)"

install:
	bash scripts/install.sh

uninstall:
	bash scripts/uninstall.sh

package:
	VERSION=$(VERSION) bash scripts/package.sh

resources/AppIcon.icns: assets/logo.png scripts/generate-icon.sh
	bash scripts/generate-icon.sh

clean:
	rm -rf $(BUILD_DIR)
