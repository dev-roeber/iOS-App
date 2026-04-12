# LH2GPX — Build / Deploy / Run Makefile
#
# Usage:
#   make build            — Debug-Build
#   make deploy           — Build + Install + Launch auf allen verbundenen Geräten
#   make deploy15         — nur iPhone 15 Pro Max
#   make deploy12         — nur iPhone 12 Pro Max
#   make devices          — verbundene Geräte anzeigen
#   make clean            — Build-Artefakte löschen
#
# Geräte werden dynamisch per Name aufgelöst (robust gegen UUID-Änderungen).

DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
XCRUN        := /usr/bin/xcrun
XCODEBUILD   := $(DEVELOPER_DIR)/usr/bin/xcodebuild
PROJECT      := LH2GPXWrapper.xcodeproj
SCHEME       := LH2GPXWrapper
BUNDLE_ID    := de.roeber.LH2GPXWrapper
CONFIG       := Debug
DERIVED_DATA := $(HOME)/Library/Developer/Xcode/DerivedData
APP_PATH      = $(shell find $(DERIVED_DATA)/LH2GPXWrapper-*/Build/Products/$(CONFIG)-iphoneos/LH2GPXWrapper.app -maxdepth 0 2>/dev/null | head -1)

# Geräte-UUIDs dynamisch per Gerätename auflösen (Spalte 3 in devicectl-Ausgabe)
UDID_15 = $(shell $(XCRUN) devicectl list devices 2>/dev/null | awk '/iPhone_15_Pro_Max/ {print $$3}')
UDID_12 = $(shell $(XCRUN) devicectl list devices 2>/dev/null | awk '/iPhone_12_Pro_Max/ {print $$3}')

.PHONY: build deploy deploy15 deploy12 devices clean \
        _build _install15 _launch15 _install12 _launch12

## Verbundene Geräte anzeigen
devices:
	@$(XCRUN) devicectl list devices

## Debug-Build (kein Deploy)
build: _build

## Build + Deploy + Launch auf allen verbundenen Geräten
deploy: _build _install15 _launch15 _install12 _launch12

## Nur iPhone 15 Pro Max
deploy15: _build _install15 _launch15

## Nur iPhone 12 Pro Max
deploy12: _build _install12 _launch12

_build:
	@echo "▶ Building $(SCHEME) [$(CONFIG)]…"
	@DEVELOPER_DIR=$(DEVELOPER_DIR) $(XCODEBUILD) \
	  -project $(PROJECT) \
	  -scheme $(SCHEME) \
	  -destination "generic/platform=iOS" \
	  -configuration $(CONFIG) \
	  -allowProvisioningUpdates \
	  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5

_install15:
	@if [ -z "$(UDID_15)" ]; then echo "⚠  iPhone 15 Pro Max nicht verbunden — skip."; exit 0; fi
	@echo "▶ Installing on iPhone 15 Pro Max ($(UDID_15))…"
	@$(XCRUN) devicectl device install app \
	  --device $(UDID_15) "$(APP_PATH)" 2>&1 | grep -E "(bundleID|Error)" | head -3

_launch15:
	@if [ -z "$(UDID_15)" ]; then exit 0; fi
	@echo "▶ Launching on iPhone 15 Pro Max…"
	@$(XCRUN) devicectl device process launch \
	  --device $(UDID_15) $(BUNDLE_ID) 2>&1 | tail -2

_install12:
	@if [ -z "$(UDID_12)" ]; then echo "⚠  iPhone 12 Pro Max nicht verbunden — skip."; exit 0; fi
	@echo "▶ Installing on iPhone 12 Pro Max ($(UDID_12))…"
	@$(XCRUN) devicectl device install app \
	  --device $(UDID_12) "$(APP_PATH)" 2>&1 | grep -E "(bundleID|Error)" | head -3

_launch12:
	@if [ -z "$(UDID_12)" ]; then exit 0; fi
	@echo "▶ Launching on iPhone 12 Pro Max…"
	@$(XCRUN) devicectl device process launch \
	  --device $(UDID_12) $(BUNDLE_ID) 2>&1 | tail -2

clean:
	@DEVELOPER_DIR=$(DEVELOPER_DIR) $(XCODEBUILD) \
	  -project $(PROJECT) -scheme $(SCHEME) clean 2>&1 | tail -2
