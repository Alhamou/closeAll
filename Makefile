.PHONY: test build app dry-run check

test:
	swift test

build:
	swift build --product closeAll

app:
	./Scripts/package-app.sh

dry-run:
	swift run closeAll -- --dry-run

check: test
	swift run closeAll -- --dry-run | python3 Scripts/verify-live-plan.py
