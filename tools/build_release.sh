#!/usr/bin/env bash
# Builds release artifacts and names them after the app and its version, so
# what lands in build/outputs/ is ready to upload or hand over:
#
#   build/outputs/fulldive-vr-news-v7.0.0.aab
#   build/outputs/fulldive-vr-news-v7.0.0.apk
#
#   tools/build_release.sh          # both an App Bundle and an APK
#   tools/build_release.sh aab      # just the bundle (what Play wants)
#   tools/build_release.sh apk      # just the APK (sideloading, QA)
#
# Signing uses keys/keys.jks via FULLDIVE_KEYSTORE_PASSWORD / FULLDIVE_ALIAS /
# FULLDIVE_ALIAS_PASSWORD; without them Gradle falls back to the debug keys.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="fulldive-vr-news"
OUT_DIR="build/outputs"

# `version: 7.0.0+7000000` in pubspec.yaml -> 7.0.0
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml)"
[[ -n "$VERSION" ]] || { echo "Could not read 'version:' from pubspec.yaml" >&2; exit 1; }

if [[ $# -eq 0 ]]; then targets=(aab apk); else targets=("$@"); fi

# Gradle quietly falls back to the debug keys when these are missing, which on
# CI would produce an artifact Play rejects. Fail loudly instead.
if [[ -z "${FULLDIVE_KEYSTORE_PASSWORD:-}" || -z "${FULLDIVE_ALIAS:-}" || -z "${FULLDIVE_ALIAS_PASSWORD:-}" ]]; then
  if [[ "${ALLOW_DEBUG_SIGNING:-}" == "1" ]]; then
    echo "warning: signing credentials are unset — building with the debug keys." >&2
  else
    echo "error: FULLDIVE_KEYSTORE_PASSWORD, FULLDIVE_ALIAS and FULLDIVE_ALIAS_PASSWORD must be set." >&2
    echo "       Set ALLOW_DEBUG_SIGNING=1 to build an unpublishable debug-signed artifact anyway." >&2
    exit 1
  fi
elif [[ ! -f keys/keys.jks ]]; then
  echo "error: keys/keys.jks is missing — restore it or inject it from CI credentials." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

for target in "${targets[@]}"; do
  case "$target" in
    aab) command="appbundle"; built="build/app/outputs/bundle/release/app-release.aab" ;;
    apk) command="apk";       built="build/app/outputs/flutter-apk/app-release.apk" ;;
    *)   echo "Unknown target '$target' (expected aab or apk)" >&2; exit 1 ;;
  esac

  echo "==> flutter build $command --release"
  flutter build "$command" --release

  destination="$OUT_DIR/${APP_NAME}-v${VERSION}.${target}"
  cp "$built" "$destination"
  echo "==> $destination ($(du -h "$destination" | cut -f1))"
done
