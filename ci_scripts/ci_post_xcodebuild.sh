#!/bin/sh
# After archive: app and keyboard short versions must match, or ASC
# processes VALID then fails as Invalid Binary when attached to a version.
set -eu

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  exit 0
fi
if [ "${CI_XCODEBUILD_EXIT_CODE:-0}" != "0" ]; then
  exit 0
fi
if [ -z "${CI_ARCHIVE_PATH:-}" ] || [ ! -d "${CI_ARCHIVE_PATH}" ]; then
  echo "CI_ARCHIVE_PATH unset; skip version check"
  exit 0
fi

APP="${CI_ARCHIVE_PATH}/Products/Applications/Lyklabord.app"
KB="${APP}/PlugIns/LyklabordKeyboard.appex"
app_ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
kb_ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$KB/Info.plist")"
app_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
kb_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$KB/Info.plist")"

echo "archive versions app=${app_ver} (${app_build}) keyboard=${kb_ver} (${kb_build})"

if [ "$app_ver" != "$kb_ver" ] || [ "$app_build" != "$kb_build" ]; then
  echo "error: app/keyboard version mismatch" >&2
  exit 1
fi
