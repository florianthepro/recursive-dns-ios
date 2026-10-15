#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./Scripts/verify.sh
xcodegen generate
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro}"
xcodebuild -project RecursiveDNS.xcodeproj -scheme RecursiveDNS -destination "$DESTINATION" test
