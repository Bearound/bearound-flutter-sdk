#!/usr/bin/env bash
# Opt-in local native artifacts for app presence development.
#
# The published native SDKs pinned by this plugin do not ship the app presence API yet.
# This script builds the native Android AAR from a local checkout, checks that the local
# Android AAR and iOS checkout really contain the app presence API, and exports the
# variables the build files read:
#
#   BEAROUND_APP_PRESENCE_LOCAL=1
#   BEAROUND_NATIVE_AAR_PATH=<absolute path of the native debug AAR>
#   BEAROUND_IOS_SDK_PATH=<absolute path of the native iOS SDK checkout>
#
# Without BEAROUND_APP_PRESENCE_LOCAL=1 the build files resolve the published pins unchanged.
# Development only: never publish a wrapper built this way.
#
# Usage:
#   eval "$(scripts/app-presence-local-native.sh)"                 # export into the shell
#   scripts/app-presence-local-native.sh -- flutter build apk --debug   # run one command
#
# Options (each also read from the environment variable shown):
#   --android-sdk PATH  native Android SDK checkout (BEAROUND_ANDROID_SDK_PATH,
#                       default: <workspace>/bearound-android-sdk)
#   --ios-sdk PATH      native iOS SDK checkout (BEAROUND_IOS_SDK_PATH,
#                       default: <workspace>/bearound-ios-sdk)
#   --aar PATH          use this AAR instead of building one (skips the Gradle build)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"

ANDROID_SDK="${BEAROUND_ANDROID_SDK_PATH:-$WORKSPACE/bearound-android-sdk}"
IOS_SDK="${BEAROUND_IOS_SDK_PATH:-$WORKSPACE/bearound-ios-sdk}"
AAR=""

APP_PRESENCE_CLASS="io/bearound/sdk/models/AppPresenceConfiguration.class"
APP_PRESENCE_SWIFT="BearoundSDK/Models/AppPresence.swift"

fail() {
  echo "app-presence-local-native: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-sdk) ANDROID_SDK="${2:?--android-sdk needs a path}"; shift 2 ;;
    --ios-sdk) IOS_SDK="${2:?--ios-sdk needs a path}"; shift 2 ;;
    --aar) AAR="${2:?--aar needs a path}"; shift 2 ;;
    --) shift; break ;;
    *) fail "unknown argument: $1" ;;
  esac
done

abs_dir() {
  [[ -d "$1" ]] || fail "directory not found: $1"
  (cd "$1" && pwd)
}

IOS_SDK="$(abs_dir "$IOS_SDK")"
[[ -f "$IOS_SDK/BearoundSDK.podspec" ]] || fail "$IOS_SDK is not a native iOS SDK checkout (no BearoundSDK.podspec)"
[[ -f "$IOS_SDK/$APP_PRESENCE_SWIFT" ]] || fail "native iOS SDK at $IOS_SDK does not contain the app presence API ($APP_PRESENCE_SWIFT)"

if [[ -z "$AAR" ]]; then
  ANDROID_SDK="$(abs_dir "$ANDROID_SDK")"
  [[ -x "$ANDROID_SDK/gradlew" ]] || fail "$ANDROID_SDK is not a native Android SDK checkout (no gradlew)"
  echo "app-presence-local-native: building $ANDROID_SDK :sdk:assembleDebug" >&2
  (cd "$ANDROID_SDK" && ./gradlew -q :sdk:assembleDebug) >&2 || fail "native Android build failed"
  AAR="$ANDROID_SDK/sdk/build/outputs/aar/sdk-debug.aar"
fi

[[ -f "$AAR" ]] || fail "AAR not found: $AAR"
AAR="$(cd "$(dirname "$AAR")" && pwd)/$(basename "$AAR")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -p "$AAR" classes.jar > "$TMP/classes.jar" 2>/dev/null || fail "$AAR has no classes.jar"
unzip -Z1 "$TMP/classes.jar" > "$TMP/classes.txt" 2>/dev/null || fail "$AAR has an unreadable classes.jar"
grep -qx "$APP_PRESENCE_CLASS" "$TMP/classes.txt" \
  || fail "AAR $AAR does not contain the app presence API ($APP_PRESENCE_CLASS); it looks like an older native release"

export BEAROUND_APP_PRESENCE_LOCAL=1
export BEAROUND_NATIVE_AAR_PATH="$AAR"
export BEAROUND_IOS_SDK_PATH="$IOS_SDK"

rm -rf "$TMP"
trap - EXIT

if [[ $# -gt 0 ]]; then
  exec "$@"
fi

printf 'export BEAROUND_APP_PRESENCE_LOCAL=1\n'
printf 'export BEAROUND_NATIVE_AAR_PATH=%q\n' "$AAR"
printf 'export BEAROUND_IOS_SDK_PATH=%q\n' "$IOS_SDK"
