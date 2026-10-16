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
INSTALLED_XCODE=""
XCODES=""
KEEPALIVE=""
SUCCESS=0
mkdir -p "$TOOLS" "$LOGS" "$PACKAGE"

say(){ printf '\n==> %s\n' "$*"; }
die(){ printf '\nFEHLER: %s\n' "$*" >&2; exit 1; }
version_ge(){
  awk -v have="$1" -v need="$2" 'BEGIN {
    split(have,h,"."); split(need,n,".");
    for (i=1;i<=4;i++) { hv=(h[i]==""?0:h[i])+0; nv=(n[i]==""?0:n[i])+0; if (hv>nv) exit 0; if (hv<nv) exit 1 }
    exit 0
  }'
}

cleanup(){
  local rc=$?
  set +e
  [[ -n "$KEEPALIVE" ]] && kill "$KEEPALIVE" 2>/dev/null || true
  if [[ -n "$XCODES" && -x "$XCODES" ]]; then "$XCODES" signout >/dev/null 2>&1 || true; fi
  security delete-generic-password -s "xcodes" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1 || true
  if [[ -n "$INSTALLED_XCODE" && -d "$INSTALLED_XCODE" ]]; then
    say "Entferne temporär installiertes Xcode"
    sudo rm -rf "$INSTALLED_XCODE"
    sudo xcode-select --reset >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK"
  if [[ $rc -ne 0 ]]; then printf '\nFehlgeschlagen. Temporäre Build-Dateien und installiertes Xcode wurden entfernt.\n' >&2; fi
}
trap cleanup EXIT INT TERM

[[ "$(uname -s)" == "Darwin" ]] || die "Dieses Skript läuft nur auf macOS."
ARCH="$(uname -m)"
MACOS="$(sw_vers -productVersion)"
printf 'Mac: %s, macOS %s\n' "$ARCH" "$MACOS"
version_ge "$MACOS" "15.3" || die "Xcode 16.4 benötigt macOS 15.3 oder neuer."

say "Administratorrechte vorbereiten"
sudo -v
(while true; do sudo -n true; sleep 45; kill -0 "$$" || exit; done) 2>/dev/null &
KEEPALIVE=$!

say "Lade xcodes CLI als signierte, notarized Binärdatei"
RELEASE_JSON="$WORK/xcodes-release.json"
curl -fsSL --retry 3 https://api.github.com/repos/XcodesOrg/xcodes/releases/latest -o "$RELEASE_JSON"
XCODES_URL="$(sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p' "$RELEASE_JSON" | grep -Ei '/xcodes[^/]*\.zip$' | grep -Evi '(dsym|checksum|source)' | head -n1 || true)"
[[ -n "$XCODES_URL" ]] || die "Kein geeignetes xcodes-Release gefunden."
curl -fL --retry 3 "$XCODES_URL" -o "$WORK/xcodes.zip"
ditto -x -k "$WORK/xcodes.zip" "$TOOLS/xcodes"
XCODES="$(find "$TOOLS/xcodes" -type f -name xcodes -perm +111 | head -n1 || true)"
[[ -n "$XCODES" ]] || die "xcodes-Binärdatei nicht gefunden."
"$XCODES" version

if [[ -x /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild ]]; then
  CURRENT="$(/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version | head -n1 | awk '{print $2}')"
  if version_ge "$CURRENT" "$XCODE_VERSION"; then
    say "Verwende vorhandenes Xcode $CURRENT"
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  else
    die "Vorhandenes /Applications/Xcode.app ist Version $CURRENT. Entferne oder aktualisiere es, damit das Skript nichts Bestehendes überschreibt."
  fi
else
  say "Installiere Xcode $XCODE_VERSION vollständig über SSH"
  printf 'Apple-ID (E-Mail): '
  IFS= read -r APPLE_ID
  [[ -n "$APPLE_ID" ]] || die "Apple-ID fehlt."
  export XCODES_USERNAME="$APPLE_ID"
  printf '%s\n' "xcodes fragt jetzt verdeckt nach Apple-ID-Passwort und gegebenenfalls 2FA-Code."
  "$XCODES" install "$XCODE_VERSION" --directory /Applications --experimental-unxip
  INSTALLED_XCODE="$(find /Applications -maxdepth 1 -type d -name 'Xcode*.app' -print | while IFS= read -r candidate; do
    build="$candidate/Contents/Developer/usr/bin/xcodebuild"
    [[ -x "$build" ]] || continue
    found="$($build -version 2>/dev/null | head -n1 | awk '{print $2}')"
    [[ "$found" == "$XCODE_VERSION" || "$found" == "$XCODE_VERSION.0" ]] && { printf '%s\n' "$candidate"; break; }
  done)"
  [[ -n "$INSTALLED_XCODE" ]] || die "Installiertes Xcode $XCODE_VERSION wurde nicht gefunden."
  sudo xcode-select --switch "$INSTALLED_XCODE/Contents/Developer"
fi

sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -version

say "Lade XcodeGen temporär"
XG_JSON="$WORK/xcodegen.json"
curl -fsSL --retry 3 https://api.github.com/repos/yonaskolb/XcodeGen/releases/latest -o "$XG_JSON"
XG_URL="$(sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p' "$XG_JSON" | grep -Ei '/xcodegen[^/]*\.zip$' | grep -Evi '(dsym|checksum|source)' | head -n1 || true)"
[[ -n "$XG_URL" ]] || die "Kein XcodeGen-Release gefunden."
curl -fL --retry 3 "$XG_URL" -o "$WORK/xcodegen.zip"
ditto -x -k "$WORK/xcodegen.zip" "$TOOLS/xcodegen"
XCODEGEN="$(find "$TOOLS/xcodegen" -type f -name xcodegen -perm +111 | head -n1 || true)"
[[ -n "$XCODEGEN" ]] || die "XcodeGen-Binärdatei nicht gefunden."

say "Lade Projekt-Repository"
curl -fL --retry 3 "$REPO_ARCHIVE" -o "$WORK/repo.tar.gz"
tar -xzf "$WORK/repo.tar.gz" -C "$WORK"
DOWNLOADED="$(find "$WORK" -maxdepth 1 -type d -name 'recursive-dns-ios-*' | head -n1)"
[[ -n "$DOWNLOADED" ]] || die "Repository konnte nicht entpackt werden."
mv "$DOWNLOADED" "$SRC"
cd "$SRC"
chmod +x Scripts/*.sh 2>/dev/null || true

say "Prüfe Repository"
[[ -x Scripts/verify.sh ]] && ./Scripts/verify.sh | tee "$LOGS/verify.log"

say "Erzeuge Xcode-Projekt"
"$XCODEGEN" generate | tee "$LOGS/xcodegen.log"
[[ -d RecursiveDNS.xcodeproj ]] || die "Xcode-Projekt fehlt."

say "Baue komplette App und Extension für den iOS-Simulator"
set +e
xcodebuild -project RecursiveDNS.xcodeproj -scheme "$SCHEME" -configuration Release \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  clean build 2>&1 | tee "$LOGS/build.log"
BUILD_RC=${PIPESTATUS[0]}
set -e
[[ $BUILD_RC -eq 0 ]] || die "Build fehlgeschlagen."
APP="$(find "$DERIVED/Build/Products" -type d -name 'RecursiveDNS.app' | head -n1)"
[[ -n "$APP" ]] || die "RecursiveDNS.app fehlt nach erfolgreichem Build."

say "Packe Quellcode, Xcode-Projekt, gebaute App und Logs"
mkdir -p "$PACKAGE/source" "$PACKAGE/build" "$PACKAGE/logs"
ditto "$SRC" "$PACKAGE/source/recursive-dns-ios"
ditto "$APP" "$PACKAGE/build/RecursiveDNS-Simulator.app"
cp -R "$LOGS/." "$PACKAGE/logs/"
cat > "$PACKAGE/README-FIRST.txt" <<'TXT'
Enthalten:
- vollständiges Repository mit erzeugtem Xcode-Projekt
- kompilierte, unsignierte Simulator-App
- Build-Protokolle

Die Simulator-App ist nicht auf einem echten iPhone installierbar. Nach Aktivierung des Apple Developer Program das Projekt öffnen, das bezahlte Team für App und Extension wählen, App Group sowie Network Extensions > DNS Proxy prüfen, auf einem iPhone testen und Product > Archive ausführen.
TXT
ID="$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom | head -c 5)"
ZIP="/tmp/${ID}.zip"
ditto -c -k --sequesterRsrc --keepParent "$PACKAGE" "$ZIP"
chmod 644 "$ZIP"
IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || true)"
[[ -n "$IP" ]] || IP="MAC_IP"
SUCCESS=1

clear
printf '<id.zip>: %s.zip\n\n' "$ID"
printf 'Linux/macOS/Windows PowerShell\n'
printf '<command>: scp %s@%s:%s .\n\n' "$USER" "$IP" "$ZIP"
printf 'Der Build ist fertig. Xcode, xcodes, XcodeGen, Zugangssitzung und Arbeitsdateien werden nun vom Mac entfernt.\n'
