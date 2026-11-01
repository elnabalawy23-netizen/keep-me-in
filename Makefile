APP_NAME = Keep Me In
BUNDLE   = build/$(APP_NAME).app
INSTALL  = /Applications/$(APP_NAME).app

.PHONY: app run install uninstall dev icon clean watch-idle cert release

## Build the release .app bundle into build/
app:
	scripts/build-app.sh release

## Build and launch from build/
run: app
	open "$(BUNDLE)"

## Build, copy to /Applications, and launch
install: app
	-pkill -x KeepMeIn
	rm -rf "$(INSTALL)"
	cp -R "$(BUNDLE)" "$(INSTALL)"
	open "$(INSTALL)"

uninstall:
	-pkill -x KeepMeIn
	rm -rf "$(INSTALL)"

## One-time: create the local signing certificate so updates keep their Accessibility grant
cert:
	scripts/make-signing-cert.sh

## Build, zip, and publish a GitHub release for the version in Packaging/Info.plist
release:
	scripts/release.sh

## Quick iteration without a bundle (no icon, no LSUIElement)
dev:
	swift run KeepMeIn

icon:
	scripts/make-icon.sh

clean:
	rm -rf build .build

## Live view of the system HID idle timer, handy to confirm nudges land
watch-idle:
	@while true; do printf "\rHID idle: %7.1fs  " $$(ioreg -c IOHIDSystem -d 4 | awk '/HIDIdleTime/ {print $$NF/1000000000; exit}'); sleep 1; done
