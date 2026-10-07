#!/usr/bin/env bash
set -euo pipefail

harness_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(cd "$harness_dir/../../.." && pwd)"
export JAVA_HOME="${BRIDGE_JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export ANDROID_HOME="${BRIDGE_ANDROID_SDK:-/Users/jotta/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
gradle_launcher="${BRIDGE_GRADLE_LAUNCHER:-$workspace_dir/wt-android-sdk-idle-performance-20261006/gradlew}"

[[ -x "$gradle_launcher" ]] || { echo "Existing Gradle launcher missing: $gradle_launcher" >&2; exit 1; }
"$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | grep -Eq 'version "17\.' || {
  echo "Java 17 is required" >&2; exit 1;
}
"$gradle_launcher" --version | grep -q '^Gradle 8.13$' || {
  echo "Gradle 8.13 is required" >&2; exit 1;
}

args=(-p "$harness_dir" --offline --no-daemon --console=plain --max-workers=2 -Pandroid.useAndroidX=true)
case "${1:-}" in
  regression)
    [[ $# -eq 1 ]] || exit 2
    args+=(testDebugUnitTest --tests com.example.bearound_flutter_sdk.BeaconBridgeRegressionTest)
    ;;
  benchmark)
    [[ $# -eq 2 && "$2" = /* ]] || {
      echo "Usage: bash tools/bridge-benchmark/run.sh benchmark /absolute/result.json" >&2; exit 2;
    }
    args+=(testDebugUnitTest --tests com.example.bearound_flutter_sdk.BridgeBenchmarkTest "-PbridgeOutput=$2")
    ;;
  compile)
    [[ $# -eq 1 ]] || exit 2
    args+=(compileDebugKotlin compileDebugUnitTestKotlin)
    ;;
  *)
    echo "Usage: bash tools/bridge-benchmark/run.sh regression|compile|benchmark /absolute/result.json" >&2
    exit 2
    ;;
esac

"$gradle_launcher" "${args[@]}" & bridge_pid=$!
(sleep 240; kill -9 "$bridge_pid" 2>/dev/null || true) & watchdog_pid=$!
trap 'kill "$bridge_pid" "$watchdog_pid" 2>/dev/null || true' EXIT INT TERM
set +e
wait "$bridge_pid"
bridge_status=$?
set -e
kill "$watchdog_pid" 2>/dev/null || true
trap - EXIT INT TERM
exit "$bridge_status"
