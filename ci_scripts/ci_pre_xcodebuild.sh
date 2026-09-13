#!/bin/sh
# Xcode Cloud: after project exists, before xcodebuild.
# Force CURRENT_PROJECT_VERSION onto every target so the keyboard appex
# cannot drift from the app (Invalid Binary on TestFlight).
set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
  exit 0
fi

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "CI_BUILD_NUMBER unset; leaving CURRENT_PROJECT_VERSION from project.yml"
  exit 0
fi

if [ ! -d Lyklabord.xcodeproj ]; then
  echo "Lyklabord.xcodeproj missing; ci_post_clone.sh must run first" >&2
  exit 1
fi

xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
echo "CURRENT_PROJECT_VERSION=${CI_BUILD_NUMBER} (app + keyboard)"
