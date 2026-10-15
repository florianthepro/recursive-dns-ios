#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null 2>&1; then
  command -v brew >/dev/null 2>&1 || { echo "Homebrew fehlt: https://brew.sh"; exit 1; }
  brew install xcodegen
fi
xcodegen generate
./Scripts/verify.sh
open RecursiveDNS.xcodeproj
