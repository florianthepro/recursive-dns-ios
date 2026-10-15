#!/bin/sh
set -eu
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew fehlt: https://brew.sh"
    exit 1
  fi
  brew install xcodegen
fi
xcodegen generate
open RecursiveDNS.xcodeproj
