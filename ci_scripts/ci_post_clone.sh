#!/bin/sh
# Xcode Cloud: after clone, before it looks for Lyklabord.xcodeproj.
# The xcodeproj is XcodeGen output and is gitignored.
# cwd is ci_scripts/ when Xcode Cloud runs this.
set -eu

ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
if ! command -v git-lfs >/dev/null 2>&1; then
  brew install git-lfs
fi

git lfs install --local
git lfs pull

# data/is/bin-morph.bin is LFS (~110MB). A leftover pointer compiles an
# empty mmap and ships a broken keyboard.
# Pointers are tiny text; never grep the 110MB binary.
pointers="$(git lfs ls-files -n | while IFS= read -r f; do
  [ -f "$f" ] || continue
  size="$(wc -c < "$f")"
  [ "$size" -lt 500 ] || continue
  if grep -q '^version https://git-lfs.github.com/spec/v1' "$f"; then
    printf '%s\n' "$f"
  fi
done)" || true
if [ -n "$pointers" ]; then
  echo "error: git-lfs objects are still pointers after pull:" >&2
  echo "$pointers" >&2
  exit 1
fi

xcodegen generate
test -d "$ROOT/Lyklabord.xcodeproj"
