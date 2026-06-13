BUILD_DIR := build
PREFIX ?= $(HOME)/.local
APP_DIR ?= $(HOME)/Applications
LAUNCH_AGENTS_DIR ?= $(HOME)/Library/LaunchAgents

DAEMON := $(BUILD_DIR)/finder-go-up-daemon
CLIENT := $(BUILD_DIR)/finder-go-up-client
APP_BIN := $(BUILD_DIR)/finder-go-up
APP := $(BUILD_DIR)/finder-go-up.app

CFLAGS := -framework Foundation -O2 -Wall -Wextra
APP_CFLAGS := -framework Cocoa -framework Foundation -O2 -Wall -Wextra

.PHONY: all clean install uninstall app launchagents package

all: $(DAEMON) $(CLIENT) $(APP_BIN) app

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(DAEMON): src/daemon.m src/common.h | $(BUILD_DIR)
	clang $(CFLAGS) -o $@ src/daemon.m

$(CLIENT): src/client.m src/navigate.m src/common.h src/navigate.h | $(BUILD_DIR)
	clang $(CFLAGS) -o $@ src/client.m src/navigate.m

$(APP_BIN): src/app.m src/navigate.m src/common.h src/navigate.h | $(BUILD_DIR)
	clang $(APP_CFLAGS) -o $@ src/app.m src/navigate.m

app: $(APP_BIN) resources/AppIcon.icns
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp resources/Info.plist "$(APP)/Contents/Info.plist"
	cp resources/PkgInfo "$(APP)/Contents/PkgInfo"
	cp resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"
	cp "$(APP_BIN)" "$(APP)/Contents/MacOS/finder-go-up"
	chmod +x "$(APP)/Contents/MacOS/finder-go-up"

launchagents:
	mkdir -p $(BUILD_DIR)/launchagents
	sed \
		-e 's|@@PREFIX@@|$(PREFIX)|g' \
		-e 's|@@APP_PATH@@|$(APP_DIR)/finder-go-up.app|g' \
		-e 's|@@LOG_PATH@@|/tmp/finder-go-up-daemon.log|g' \
		launchagents/daemon.plist.template > $(BUILD_DIR)/launchagents/com.acode.finder-go-up.plist
	sed \
		-e 's|@@PREFIX@@|$(PREFIX)|g' \
		-e 's|@@APP_PATH@@|$(APP_DIR)/finder-go-up.app|g' \
		launchagents/warm.plist.template > $(BUILD_DIR)/launchagents/com.acode.finder-go-up-warm.plist

install: all launchagents
	bash scripts/install.sh

package:
	bash scripts/package.sh

uninstall:
	bash scripts/uninstall.sh

resources/AppIcon.icns: assets/logo.png scripts/generate-icon.sh
	bash scripts/generate-icon.sh

clean:
	rm -rf $(BUILD_DIR)
