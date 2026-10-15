#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./Scripts/verify.sh
xcodegen generate
rm -rf build/RecursiveDNS.xcarchive
xcodebuild -project RecursiveDNS.xcodeproj -scheme RecursiveDNS -configuration Release -destination 'generic/platform=iOS' -archivePath build/RecursiveDNS.xcarchive archive
printf 'Archiv: %s
' "$PWD/build/RecursiveDNS.xcarchive"
