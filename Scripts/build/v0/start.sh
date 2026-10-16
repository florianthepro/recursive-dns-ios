#!/bin/bash
set -Eeuo pipefail

REPO_ARCHIVE="https://github.com/florianthepro/recursive-dns-ios/archive/refs/heads/main.tar.gz"
XCODE_VERSION="16.4"
SCHEME="RecursiveDNS"

WORK="$(mktemp -d /tmp/recursive-dns-build.XXXXXX)"
TOOLS="$WORK/tools"
SRC="$WORK/recursive-dns-ios"
DERIVED="$WORK/DerivedData"
LOGS="$WORK/logs"
PACKAGE="$WORK/package"
BEFORE_RUNTIMES="$WORK/runtimes-before.txt"
AFTER_RUNTIMES="$WORK/runtimes-after.txt"
NEW_RUNTIMES="$WORK/runtimes-new.txt"

XCODES=""
XCODEGEN=""
INSTALLED_XCODE=""
KEEPALIVE=""
RESULT_ZIP=""
BUILD_OK=0

mkdir -p "$TOOLS" "$LOGS" "$PACKAGE"
: > "$BEFORE_RUNTIMES"
: > "$AFTER_RUNTIMES"
: > "$NEW_RUNTIMES"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nFEHLER: %s\n' "$*" >&2; exit 1; }

version_ge() {
  awk -v have="$1" -v need="$2" 'BEGIN {
    split(have,h,"."); split(need,n,".");
    for (i=1;i<=4;i++) {
      hv=(h[i]==""?0:h[i])+0;
      nv=(n[i]==""?0:n[i])+0;
      if (hv>nv) exit 0;
      if (hv<nv) exit 1;
    }
    exit 0;
  }'
}

runtime_ids() {
  xcrun simctl runtime list 2>/dev/null \
    | sed -nE 's/.* - ([0-9A-Fa-f-]{36}) \(.*/\1/p' \
    | sort -u
}

make_result_zip() {
  local result_type="$1"
  local id
  id="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 5)"
  RESULT_ZIP="/tmp/${id}.zip"

  mkdir -p "$PACKAGE/logs"
  cp -R "$LOGS/." "$PACKAGE/logs/" 2>/dev/null || true

  if [[ -d "$SRC" ]]; then
    mkdir -p "$PACKAGE/source"
    ditto "$SRC" "$PACKAGE/source/recursive-dns-ios" 2>/dev/null || true
  fi

  if [[ "$result_type" == "success" ]]; then
    cat > "$PACKAGE/README-FIRST.txt" <<'TXT'
Build erfolgreich.

Enthalten:
- source/recursive-dns-ios: vollständiges Repository mit erzeugtem Xcode-Projekt
- build/RecursiveDNS-Simulator.app: kompilierte, unsignierte Simulator-App
- logs: Prüf-, Runtime-, Projekt- und Buildprotokolle

Die Simulator-App ist nicht auf einem echten iPhone installierbar. Nach Aktivierung des Apple Developer Program das Projekt öffnen, das bezahlte Team für App und Extension wählen, App Group sowie Network Extensions > DNS Proxy prüfen, auf einem echten iPhone testen und Product > Archive ausführen.
TXT
  else
    cat > "$PACKAGE/README-FIRST.txt" <<'TXT'
Build fehlgeschlagen.

Diese ZIP enthält den bis zum Fehler erzeugten Quellstand und sämtliche verfügbaren Protokolle. Maßgeblich ist logs/build.log beziehungsweise das letzte erzeugte Protokoll.
TXT
  fi

  ditto -c -k --sequesterRsrc --keepParent "$PACKAGE" "$RESULT_ZIP"
  chmod 644 "$RESULT_ZIP"
}

print_download() {
  local ip
  ip="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true)"
  [[ -n "$ip" ]] || ip="MAC_IP"
  printf '\n<id.zip>: %s\n\n' "$(basename "$RESULT_ZIP")"
  printf 'Linux/macOS/Windows PowerShell\n'
  printf '<command>: scp %s@%s:%s .\n' "$USER" "$ip" "$RESULT_ZIP"
}

cleanup() {
  local rc=$?
  set +e

  [[ -n "$KEEPALIVE" ]] && kill "$KEEPALIVE" 2>/dev/null || true

  if [[ -n "$XCODES" && -x "$XCODES" ]]; then
    "$XCODES" signout >/dev/null 2>&1 || true
  fi

  if [[ -s "$NEW_RUNTIMES" ]] && command -v xcrun >/dev/null 2>&1; then
    say "Entferne nur die von diesem Lauf installierten Simulator-Runtimes"
    while IFS= read -r runtime_id; do
      [[ -n "$runtime_id" ]] || continue
      xcrun simctl runtime delete "$runtime_id" >/dev/null 2>&1 || true
    done < "$NEW_RUNTIMES"
  fi

  if [[ -n "$INSTALLED_XCODE" && -d "$INSTALLED_XCODE" ]]; then
    say "Entferne das von diesem Lauf installierte Xcode"
    sudo rm -rf "$INSTALLED_XCODE"
    sudo xcode-select --reset >/dev/null 2>&1 || true
  fi

  rm -rf "$WORK"

  if [[ $rc -ne 0 ]]; then
    printf '\nDer Vorgang ist fehlgeschlagen. Temporäre Komponenten wurden entfernt.\n' >&2
  fi
}
trap cleanup EXIT INT TERM

on_error() {
  local rc=$?
  set +e
  if [[ -z "$RESULT_ZIP" ]]; then
    make_result_zip failure
    print_download
  fi
  exit "$rc"
}
trap on_error ERR

[[ "$(uname -s)" == "Darwin" ]] || die "Dieses Skript läuft nur auf macOS."
ARCH="$(uname -m)"
MACOS="$(sw_vers -productVersion)"
printf 'Mac: %s, macOS %s\n' "$ARCH" "$MACOS"
version_ge "$MACOS" "15.3" || die "Xcode 16.4 benötigt macOS 15.3 oder neuer."

say "Administratorrechte vorbereiten"
sudo -v
(while true; do sudo -n true; sleep 45; kill -0 "$$" || exit; done) 2>/dev/null &
KEEPALIVE=$!

say "Lade xcodes CLI temporär"
XCODES_JSON="$WORK/xcodes-release.json"
curl -fsSL --retry 3 https://api.github.com/repos/XcodesOrg/xcodes/releases/latest -o "$XCODES_JSON"
XCODES_URL="$(sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p' "$XCODES_JSON" | grep -Ei '/xcodes[^/]*\.zip$' | grep -Evi '(dsym|checksum|source)' | head -n 1 || true)"
[[ -n "$XCODES_URL" ]] || die "Kein passendes xcodes-Release gefunden."
curl -fL --retry 3 "$XCODES_URL" -o "$WORK/xcodes.zip"
ditto -x -k "$WORK/xcodes.zip" "$TOOLS/xcodes"
XCODES="$(find "$TOOLS/xcodes" -type f -name xcodes -perm +111 | head -n 1 || true)"
[[ -n "$XCODES" ]] || die "xcodes wurde im Release nicht gefunden."
"$XCODES" version

EXISTING_XCODE=""
while IFS= read -r candidate; do
  build="$candidate/Contents/Developer/usr/bin/xcodebuild"
  [[ -x "$build" ]] || continue
  found="$($build -version 2>/dev/null | head -n 1 | awk '{print $2}')"
  if version_ge "$found" "$XCODE_VERSION"; then
    EXISTING_XCODE="$candidate"
    break
  fi
done < <(find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print 2>/dev/null)

if [[ -n "$EXISTING_XCODE" ]]; then
  say "Verwende vorhandenes Xcode: $EXISTING_XCODE"
  sudo xcode-select --switch "$EXISTING_XCODE/Contents/Developer"
else
  say "Installiere Xcode $XCODE_VERSION vollständig über SSH"
  printf 'Apple-ID (E-Mail): '
  IFS= read -r APPLE_ID
  [[ -n "$APPLE_ID" ]] || die "Apple-ID fehlt."
  export XCODES_USERNAME="$APPLE_ID"
  printf '%s\n' "xcodes fragt verdeckt nach Apple-ID-Passwort und gegebenenfalls 2FA-Code."
  "$XCODES" install "$XCODE_VERSION" --directory /Applications --experimental-unxip

  while IFS= read -r candidate; do
    build="$candidate/Contents/Developer/usr/bin/xcodebuild"
    [[ -x "$build" ]] || continue
    found="$($build -version 2>/dev/null | head -n 1 | awk '{print $2}')"
    if [[ "$found" == "$XCODE_VERSION" || "$found" == "$XCODE_VERSION.0" ]]; then
      INSTALLED_XCODE="$candidate"
      break
    fi
  done < <(find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print 2>/dev/null)

  [[ -n "$INSTALLED_XCODE" ]] || die "Das installierte Xcode $XCODE_VERSION wurde nicht gefunden."
  sudo xcode-select --switch "$INSTALLED_XCODE/Contents/Developer"
fi

sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version

runtime_ids > "$BEFORE_RUNTIMES" || true

say "Installiere die aktuelle iOS-Simulator-Runtime"
xcodebuild -downloadPlatform iOS 2>&1 | tee "$LOGS/platform-download.log"

runtime_ids > "$AFTER_RUNTIMES" || true
comm -13 "$BEFORE_RUNTIMES" "$AFTER_RUNTIMES" > "$NEW_RUNTIMES" || true
xcrun simctl runtime list | tee "$LOGS/runtimes.log"
xcodebuild -showsdks | tee "$LOGS/sdks.log"

if ! xcrun simctl runtime list | grep -Eq '^iOS [0-9.]+ .*\(Ready\)$'; then
  die "Es wurde keine betriebsbereite iOS-Simulator-Runtime registriert."
fi

say "Lade XcodeGen temporär"
XG_JSON="$WORK/xcodegen-release.json"
curl -fsSL --retry 3 https://api.github.com/repos/yonaskolb/XcodeGen/releases/latest -o "$XG_JSON"
XG_URL="$(sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p' "$XG_JSON" | grep -Ei '/xcodegen[^/]*\.zip$' | grep -Evi '(dsym|checksum|source)' | head -n 1 || true)"
[[ -n "$XG_URL" ]] || die "Kein passendes XcodeGen-Release gefunden."
curl -fL --retry 3 "$XG_URL" -o "$WORK/xcodegen.zip"
ditto -x -k "$WORK/xcodegen.zip" "$TOOLS/xcodegen"
XCODEGEN="$(find "$TOOLS/xcodegen" -type f -name xcodegen -perm +111 | head -n 1 || true)"
[[ -n "$XCODEGEN" ]] || die "XcodeGen wurde im Release nicht gefunden."
"$XCODEGEN" --version

say "Lade das aktuelle Projekt-Repository"
curl -fL --retry 3 "$REPO_ARCHIVE" -o "$WORK/repository.tar.gz"
tar -xzf "$WORK/repository.tar.gz" -C "$WORK"
DOWNLOADED="$(find "$WORK" -maxdepth 1 -type d -name 'recursive-dns-ios-*' | head -n 1 || true)"
[[ -n "$DOWNLOADED" ]] || die "Das GitHub-Repository konnte nicht entpackt werden."
mv "$DOWNLOADED" "$SRC"
cd "$SRC"
chmod +x Scripts/*.sh 2>/dev/null || true

say "Prüfe Repository"
if [[ -x Scripts/verify.sh ]]; then
  ./Scripts/verify.sh 2>&1 | tee "$LOGS/verify.log"
fi

say "Erzeuge Xcode-Projekt"
"$XCODEGEN" generate 2>&1 | tee "$LOGS/xcodegen.log"
[[ -d RecursiveDNS.xcodeproj ]] || die "RecursiveDNS.xcodeproj wurde nicht erzeugt."

say "Prüfe verfügbare Build-Ziele"
xcodebuild -project RecursiveDNS.xcodeproj -scheme "$SCHEME" -showdestinations 2>&1 | tee "$LOGS/destinations.log"
if ! grep -q 'platform:iOS Simulator' "$LOGS/destinations.log"; then
  die "Xcode meldet kein iOS-Simulator-Ziel."
fi

say "Baue App und DNS-Proxy-Extension für den iOS-Simulator"
set +e
xcodebuild \
  -project RecursiveDNS.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build 2>&1 | tee "$LOGS/build.log"
BUILD_RC=${PIPESTATUS[0]}
set -e
[[ $BUILD_RC -eq 0 ]] || die "Der Xcode-Build ist fehlgeschlagen."

APP="$(find "$DERIVED/Build/Products" -type d -path '*Release-iphonesimulator/RecursiveDNS.app' | head -n 1 || true)"
[[ -n "$APP" && -d "$APP" ]] || die "RecursiveDNS.app wurde nach erfolgreichem Build nicht gefunden."

say "Packe Repository, Xcode-Projekt, Simulator-App und Protokolle"
mkdir -p "$PACKAGE/build"
ditto "$APP" "$PACKAGE/build/RecursiveDNS-Simulator.app"
BUILD_OK=1
make_result_zip success

clear
print_download
printf '\nDer Build ist fertig. Von diesem Lauf installierte Komponenten werden jetzt sauber entfernt.\n'
