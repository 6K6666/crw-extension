#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_IOS=0
RUN_MACOS=0
RUN_CHECKS=0
SYNC_RESOURCES=1

usage() {
  cat <<'USAGE'
Usage:
  scripts/package-release.sh [all|ios|macos] [--check] [--skip-sync]

Targets:
  all       Package the AltStore IPA and macOS DMG. This is the default.
  ios       Package only the AltStore IPA.
  macos     Package only the macOS DMG.

Options:
  --check      Run npm run check before packaging.
  --skip-sync  Do not rebuild/sync Safari extension resources first.
  -h, --help   Show this help text.

macOS signing/notarization environment:
  TEAM_ID                  Apple Developer team ID.
  NOTARY_PROFILE           notarytool keychain profile, for example crw-notary.
  MACOS_SIGNING_IDENTITY   Optional explicit Developer ID Application identity.

Examples:
  npm run package:release
  TEAM_ID="APPLE_TEAM_ID" NOTARY_PROFILE="crw-notary" npm run package:release
  npm run package:release -- ios
  npm run package:release -- macos --check
USAGE
}

select_all_targets() {
  RUN_IOS=1
  RUN_MACOS=1
}

if [[ $# -eq 0 ]]; then
  select_all_targets
fi

for arg in "$@"; do
  case "$arg" in
    all)
      select_all_targets
      ;;
    ios)
      RUN_IOS=1
      ;;
    macos)
      RUN_MACOS=1
      ;;
    --check)
      RUN_CHECKS=1
      ;;
    --skip-sync)
      SYNC_RESOURCES=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$RUN_IOS" -eq 0 && "$RUN_MACOS" -eq 0 ]]; then
  select_all_targets
fi

run_step() {
  echo
  echo "==> $*"
  "$@"
}

latest_artifact() {
  local artifact_dir="$1"
  local pattern="$2"

  find "$artifact_dir" -maxdepth 1 -type f -name "$pattern" -print 2>/dev/null |
    sort |
    tail -n 1
}

cd "$ROOT_DIR"

if [[ "$RUN_CHECKS" -eq 1 ]]; then
  run_step npm run check
fi

if [[ "$SYNC_RESOURCES" -eq 1 ]]; then
  run_step npm run sync-safari-resources
fi

if [[ "$RUN_MACOS" -eq 1 && -z "${NOTARY_PROFILE:-}" ]]; then
  echo
  echo "NOTARY_PROFILE is not set. The macOS package script will skip notarization."
fi

declare -a ARTIFACTS=()

if [[ "$RUN_IOS" -eq 1 ]]; then
  run_step "$ROOT_DIR/scripts/package-altstore-ipa.sh"
  IPA_PATH="$(latest_artifact "$ROOT_DIR/build/altstore" "*.ipa")"
  if [[ -n "$IPA_PATH" ]]; then
    ARTIFACTS+=("$IPA_PATH")
  fi
fi

if [[ "$RUN_MACOS" -eq 1 ]]; then
  run_step "$ROOT_DIR/scripts/package-macos-dmg.sh"
  DMG_PATH="$(latest_artifact "$ROOT_DIR/build/macos-dmg" "*.dmg")"
  if [[ -n "$DMG_PATH" ]]; then
    ARTIFACTS+=("$DMG_PATH")
  fi
fi

echo
echo "Release packaging complete."
if [[ "${#ARTIFACTS[@]}" -gt 0 ]]; then
  echo "Artifacts:"
  printf '  %s\n' "${ARTIFACTS[@]}"
fi
