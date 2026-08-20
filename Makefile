-include .env

SCHEME       := Haystack
PROJECT      := Haystack.xcodeproj
BUNDLE_ID    := app.haystack
DESTINATION  := platform=iOS Simulator,name=$(SIMULATOR)
CONFIGURATION ?= Debug
DERIVED_DATA := $(CURDIR)/.derivedData
APP_PATH     := $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)-iphonesimulator/$(SCHEME).app
ARCHIVE_PATH := $(CURDIR)/archive/Haystack.xcarchive

.PHONY: generate build launch test archive clean

generate:
	xcodegen generate

build: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		build

launch: build
	xcrun simctl bootstatus "$(SIMULATOR)" -b
	open -a Simulator
	xcrun simctl install booted "$(APP_PATH)"
	xcrun simctl launch booted $(BUNDLE_ID)

test: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		test

archive: generate
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath $(ARCHIVE_PATH) \
		-derivedDataPath $(DERIVED_DATA) \
		archive

clean:
	rm -rf $(PROJECT) $(DERIVED_DATA) archive
