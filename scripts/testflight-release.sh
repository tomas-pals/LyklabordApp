#!/usr/bin/env bash
# Headless TestFlight release — same steps as docs/TESTFLIGHT.md.
# Local: isolated git worktree. CI: the Actions checkout is already isolated.
set -euo pipefail

APP_ID="${APP_ID:-}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"
INTERNAL_GROUP_ID="${INTERNAL_GROUP_ID:-}"
EXTERNAL_GROUP_ID="${EXTERNAL_GROUP_ID:-}"
ASSIGN_INTERNAL="${ASSIGN_INTERNAL:-1}"
ASSIGN_EXTERNAL="${ASSIGN_EXTERNAL:-0}"
DRY_RUN="${DRY_RUN:-0}"

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

asc_bin() {
  if command -v asccli >/dev/null 2>&1; then
    echo asccli
  elif command -v asc >/dev/null 2>&1; then
    echo asc
  else
    echo "asccli not on PATH (brew install asccli)" >&2
    exit 1
  fi
}

marketing_version() {
  python3 - <<'PY'
import re
from pathlib import Path
text = Path("project.yml").read_text()
m = re.search(r'(?m)^    MARKETING_VERSION:\s+"([^"]+)"', text)
if not m:
    raise SystemExit("could not read project.yml settings.base MARKETING_VERSION")
print(m.group(1))
PY
}

next_build_number() {
  local version="$1" raw
  raw="$("$ASC" builds next-number \
    --app-id "$APP_ID" \
    --version "$version" \
    --platform ios \
    --output json 2>/dev/null || true)"
  python3 -c '
import json, re, sys
raw = sys.argv[1]
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    m = re.search(r"\b(\d+)\b", raw)
    if not m:
        sys.exit("asccli builds next-number: no number in output")
    print(m.group(1))
    raise SystemExit
if isinstance(data, dict):
    for key in ("nextNumber", "next_number", "buildNumber", "number", "value"):
        if key in data and data[key] is not None:
            print(data[key])
            raise SystemExit
    if "data" in data:
        print(data["data"])
        raise SystemExit
print(data)
' "$raw"
}

if [[ -z "${RELEASE_VERSION:-}" ]]; then
  RELEASE_VERSION="$(marketing_version)"
fi
if [[ -z "${BETA_NOTES:-}" ]]; then
  BETA_NOTES="$(git log -1 --pretty=%s)"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "dry-run: team=45BXWF6V3P version=${RELEASE_VERSION} build=${RELEASE_BUILD:-<next-number>} notes=${BETA_NOTES}"
  echo "dry-run: would xcodegen + archive + export + asccli upload app ${APP_ID:-<APP_ID>}"
  exit 0
fi

: "${APP_ID:?set APP_ID to your App Store Connect app id}"
: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH to the AuthKey_*.p8 file}"
if [[ ! -f "$ASC_KEY_PATH" ]]; then
  echo "ASC_KEY_PATH not a file: $ASC_KEY_PATH" >&2
  exit 1
fi

ASC="$(asc_bin)"
export ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY_PATH="$ASC_KEY_PATH"

if [[ -z "${RELEASE_BUILD:-}" ]]; then
  RELEASE_BUILD="$(next_build_number "$RELEASE_VERSION")"
fi

echo "TestFlight ${RELEASE_VERSION} (${RELEASE_BUILD}) — ${BETA_NOTES}"

USE_WORKTREE=0
if [[ -z "${GITHUB_ACTIONS:-}" && -z "${SKIP_WORKTREE:-}" ]]; then
  USE_WORKTREE=1
  RELEASE_PARENT="$(mktemp -d /tmp/lyklabord-release.XXXXXX)"
  RELEASE_WORKTREE="$RELEASE_PARENT/checkout"
  git worktree add --detach "$RELEASE_WORKTREE" HEAD
  cd "$RELEASE_WORKTREE"
fi

cleanup() {
  if [[ "$USE_WORKTREE" == "1" ]]; then
    git -C "$RELEASE_WORKTREE" restore App/BuildInfo.swift >/dev/null 2>&1 || true
    git worktree remove --force "$RELEASE_WORKTREE"
    rmdir "$RELEASE_PARENT" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

xcodegen generate

mkdir -p build
set -o pipefail

xcodebuild \
  -project Lyklabord.xcodeproj \
  -scheme Lyklabord \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/Lyklabord.xcarchive \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  MARKETING_VERSION="$RELEASE_VERSION" \
  CURRENT_PROJECT_VERSION="$RELEASE_BUILD" \
  archive 2>&1 | tee build/archive.log

app_ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/Lyklabord.xcarchive/Products/Applications/Lyklabord.app/Info.plist)"
kb_ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
  build/Lyklabord.xcarchive/Products/Applications/Lyklabord.app/PlugIns/LyklabordKeyboard.appex/Info.plist)"
if [[ "$app_ver" != "$RELEASE_VERSION" || "$kb_ver" != "$RELEASE_VERSION" ]]; then
  echo "version mismatch: app=${app_ver} keyboard=${kb_ver} expected=${RELEASE_VERSION}" >&2
  exit 1
fi

xcodebuild \
  -exportArchive \
  -archivePath build/Lyklabord.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist "$ROOT/docs/TestFlightExportOptions.plist" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  2>&1 | tee build/export.log

IPA="$(find build/export -name '*.ipa' -print -quit)"
if [[ -z "$IPA" ]]; then
  echo "no IPA in build/export" >&2
  exit 1
fi

KEEP="$ROOT/.build/testflight-${RELEASE_VERSION}-${RELEASE_BUILD}"
mkdir -p "$KEEP"
cp "$IPA" "$KEEP/Lyklabord-${RELEASE_VERSION}-${RELEASE_BUILD}.ipa"
IPA="$KEEP/Lyklabord-${RELEASE_VERSION}-${RELEASE_BUILD}.ipa"

"$ASC" builds upload \
  --app-id "$APP_ID" \
  --file "$IPA" \
  --version "$RELEASE_VERSION" \
  --build-number "$RELEASE_BUILD" \
  --platform ios \
  --wait \
  --output json | tee build/upload.json

ASC_BUILD_ID="$(python3 -c '
import json, sys
from pathlib import Path
data = json.loads(Path("build/upload.json").read_text())
if isinstance(data, dict):
    for key in ("id", "buildId", "build_id"):
        if key in data and data[key]:
            print(data[key]); raise SystemExit
    nested = data.get("data") or data.get("build") or {}
    if isinstance(nested, dict):
        for key in ("id", "buildId"):
            if nested.get(key):
                print(nested[key]); raise SystemExit
raise SystemExit("could not parse build id from upload.json")
')"

"$ASC" builds set-encryption-compliance \
  --build-id "$ASC_BUILD_ID" \
  --uses-non-exempt-encryption false \
  --output table || true

"$ASC" builds update-beta-notes \
  --build-id "$ASC_BUILD_ID" \
  --locale en-US \
  --notes "$BETA_NOTES" \
  --output table || true

if [[ "$ASSIGN_INTERNAL" == "1" && -n "$INTERNAL_GROUP_ID" ]]; then
  "$ASC" builds add-beta-group \
    --build-id "$ASC_BUILD_ID" \
    --beta-group-id "$INTERNAL_GROUP_ID" \
    --output table
fi

if [[ "$ASSIGN_EXTERNAL" == "1" && -n "$EXTERNAL_GROUP_ID" ]]; then
  "$ASC" builds add-beta-group \
    --build-id "$ASC_BUILD_ID" \
    --beta-group-id "$EXTERNAL_GROUP_ID" \
    --output table
fi

echo "uploaded build id=${ASC_BUILD_ID} version=${RELEASE_VERSION} number=${RELEASE_BUILD}"
