#!/usr/bin/env bash
# Integration test for the opt-in local native artifacts (scripts/app-presence-local-native.sh).
# Builds for real: Gradle (plugin + example host), CocoaPods (example host). Needs Flutter,
# CocoaPods, a JDK and the two native checkouts that carry the app presence API.
#
# Usage: scripts/app-presence-local-native.test.sh [--android-sdk PATH] [--ios-sdk PATH]
#   (defaults: BEAROUND_ANDROID_SDK_PATH / BEAROUND_IOS_SDK_PATH, then the workspace siblings)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
ANDROID_SDK="${BEAROUND_ANDROID_SDK_PATH:-$WORKSPACE/bearound-android-sdk}"
IOS_SDK="${BEAROUND_IOS_SDK_PATH:-$WORKSPACE/bearound-ios-sdk}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --android-sdk) ANDROID_SDK="$2"; shift 2 ;;
    --ios-sdk) IOS_SDK="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
unset BEAROUND_APP_PRESENCE_LOCAL BEAROUND_NATIVE_AAR_PATH BEAROUND_IOS_SDK_PATH BEAROUND_ANDROID_SDK_PATH

SCRIPT="$ROOT/scripts/app-presence-local-native.sh"
EXAMPLE="$ROOT/example"
PLUGIN=":bearound_flutter_sdk"
APP_PRESENCE_CLASS="io/bearound/sdk/models/AppPresenceConfiguration.class"
APP_PRESENCE_DEX_TYPE="Lio/bearound/sdk/models/AppPresenceConfiguration;"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0
pass() { PASSED=$((PASSED + 1)); echo "ok - $1"; }
fail() { FAILED=$((FAILED + 1)); echo "not ok - $1"; [[ -n "${2:-}" ]] && sed 's/^/    /' "$2" | tail -20; }

# Release pins as declared in the build files (the values the default build must resolve).
ANDROID_PIN="$(grep -oE "bearound-android-sdk:v?[0-9.]+" "$ROOT/android/build.gradle" | head -1 | sed -E 's/.*:v?//')"
IOS_PIN="$(grep -oE "dependency 'BearoundSDK', '[0-9.]+'" "$ROOT/ios/bearound_flutter_sdk.podspec" | head -1 | grep -oE "[0-9.]+'$" | tr -d "'")"
[[ -n "$ANDROID_PIN" && -n "$IOS_PIN" ]] || { echo "could not read the release pins" >&2; exit 1; }

gradle_host() { (cd "$EXAMPLE/android" && ./gradlew -q "$@"); }

# Prints every classes jar on the plugin debug compile classpath, one per line.
cat > "$TMP/classpath.gradle" <<'GRADLE'
gradle.projectsEvaluated { g ->
    def plugin = g.rootProject.findProject(':bearound_flutter_sdk')
    if (plugin == null) return
    plugin.tasks.register('printBearoundCompileClasspath') {
        def jars = plugin.configurations.debugCompileClasspath.incoming.artifactView {
            attributes { attribute(Attribute.of('artifactType', String), 'android-classes-jar') }
        }.files
        doLast { jars.each { println "CP=${it}" } }
    }
}
GRADLE

classpath_has_app_presence() {
  local jar
  while read -r jar; do
    unzip -Z1 "$jar" > "$TMP/jar.txt" 2>/dev/null && grep -qx "$APP_PRESENCE_CLASS" "$TMP/jar.txt" && return 0
  done < <(sed -n 's/^CP=//p' "$1")
  return 1
}

# Old published artifacts: an AAR and an iOS checkout without the app presence API.
mkdir -p "$TMP/old-aar/io/bearound/sdk" "$TMP/old-ios/BearoundSDK"
printf 'old' > "$TMP/old-aar/io/bearound/sdk/BeAroundSDK.class"
(cd "$TMP/old-aar" && zip -qr classes.jar io && printf '<manifest package="io.bearound.sdk"/>' > AndroidManifest.xml && zip -q old.aar classes.jar AndroidManifest.xml)
OLD_AAR="$TMP/old-aar/old.aar"
cp "$IOS_SDK/BearoundSDK.podspec" "$TMP/old-ios/"

echo "# setup: flutter pub get + Gradle wrapper for the example host"
(cd "$EXAMPLE" && flutter pub get >/dev/null && flutter build apk --debug --config-only >/dev/null) \
  || { echo "example setup failed" >&2; exit 1; }

echo "# default (BEAROUND_APP_PRESENCE_LOCAL unset): release pins android=$ANDROID_PIN ios=$IOS_PIN"
gradle_host -I "$TMP/classpath.gradle" "$PLUGIN:printBearoundCompileClasspath" > "$TMP/default-cp.txt" 2>&1
if grep -q "bearound-android-sdk-v$ANDROID_PIN" "$TMP/default-cp.txt" && ! grep -q "sdk-debug.aar" "$TMP/default-cp.txt"; then
  pass "default: plugin compiles against published bearound-android-sdk v$ANDROID_PIN"
else
  fail "default: plugin compiles against published bearound-android-sdk v$ANDROID_PIN" "$TMP/default-cp.txt"
fi
(cd "$EXAMPLE/ios" && pod ipc spec "$ROOT/ios/bearound_flutter_sdk.podspec") > "$TMP/default-spec.json" 2>&1
if ruby -rjson -e 'exit(JSON.parse(File.read(ARGV[0]))["dependencies"]["BearoundSDK"] == [ARGV[1]] ? 0 : 1)' "$TMP/default-spec.json" "$IOS_PIN"; then
  pass "default: podspec requires BearoundSDK $IOS_PIN"
else
  fail "default: podspec requires BearoundSDK $IOS_PIN" "$TMP/default-spec.json"
fi
(cd "$EXAMPLE/ios" && pod ipc podfile "$EXAMPLE/ios/Podfile") > "$TMP/default-podfile.yml" 2>&1
if grep -q "bearound_flutter_sdk" "$TMP/default-podfile.yml" && ! grep -q "BearoundSDK" "$TMP/default-podfile.yml"; then
  pass "default: example Podfile adds no local BearoundSDK pod"
else
  fail "default: example Podfile adds no local BearoundSDK pod" "$TMP/default-podfile.yml"
fi

echo "# override: local native artifacts"
if "$SCRIPT" --android-sdk "$ANDROID_SDK" --ios-sdk "$IOS_SDK" > "$TMP/env.sh" 2> "$TMP/script.log"; then
  pass "script builds the native AAR and exports the override"
else
  fail "script builds the native AAR and exports the override" "$TMP/script.log"
  echo "1..$((PASSED + FAILED))"; echo "# passed $PASSED, failed $FAILED"; exit 1
fi
# shellcheck disable=SC1091
source "$TMP/env.sh"

gradle_host -I "$TMP/classpath.gradle" "$PLUGIN:printBearoundCompileClasspath" > "$TMP/local-cp.txt" 2>&1
if classpath_has_app_presence "$TMP/local-cp.txt" && ! grep -q "bearound-android-sdk-v" "$TMP/local-cp.txt"; then
  pass "override: plugin compile classpath has the app presence API and no published native SDK"
else
  fail "override: plugin compile classpath has the app presence API and no published native SDK" "$TMP/local-cp.txt"
fi
gradle_host "$PLUGIN:dependencies" --configuration releaseRuntimeClasspath > "$TMP/local-deps.txt" 2>&1
if grep -q "androidx.work:work-runtime-ktx" "$TMP/local-deps.txt" && ! grep -q "com.github.Bearound:bearound-android-sdk" "$TMP/local-deps.txt"; then
  pass "override: published bearound-android-sdk is not resolved; native transitive deps declared"
else
  fail "override: published bearound-android-sdk is not resolved; native transitive deps declared" "$TMP/local-deps.txt"
fi
(cd "$EXAMPLE" && flutter build apk --debug) > "$TMP/apk.log" 2>&1
APK="$EXAMPLE/build/app/outputs/flutter-apk/app-debug.apk"
if [[ -f "$APK" ]] && unzip -p "$APK" 'classes*.dex' > "$TMP/dex.bin" && LC_ALL=C grep -aqF "$APP_PRESENCE_DEX_TYPE" "$TMP/dex.bin"; then
  pass "override: plugin and host compile; host APK packages the local app presence classes"
else
  fail "override: plugin and host compile; host APK packages the local app presence classes" "$TMP/apk.log"
fi
(cd "$EXAMPLE/ios" && pod install) > "$TMP/pod.log" 2>&1
if grep -qF "BearoundSDK (from \`$BEAROUND_IOS_SDK_PATH\`)" "$EXAMPLE/ios/Podfile.lock" \
  && grep -q "AppPresence.swift" "$EXAMPLE/ios/Pods/Pods.xcodeproj/project.pbxproj"; then
  pass "override: pod install resolves BearoundSDK from the local checkout with the app presence API"
else
  fail "override: pod install resolves BearoundSDK from the local checkout with the app presence API" "$TMP/pod.log"
fi

echo "# override rejects the old published artifacts"
if "$SCRIPT" --aar "$OLD_AAR" --ios-sdk "$IOS_SDK" > /dev/null 2> "$TMP/reject-script.log"; then
  fail "script rejects an AAR without the app presence API"
else
  grep -q "does not contain the app presence API" "$TMP/reject-script.log" \
    && pass "script rejects an AAR without the app presence API" \
    || fail "script rejects an AAR without the app presence API" "$TMP/reject-script.log"
fi
if BEAROUND_NATIVE_AAR_PATH="$OLD_AAR" gradle_host "$PLUGIN:help" > "$TMP/reject-gradle.log" 2>&1; then
  fail "Gradle rejects an AAR without the app presence API"
else
  grep -q "does not contain the app presence API" "$TMP/reject-gradle.log" \
    && pass "Gradle rejects an AAR without the app presence API" \
    || fail "Gradle rejects an AAR without the app presence API" "$TMP/reject-gradle.log"
fi
if env -u BEAROUND_NATIVE_AAR_PATH bash -c 'cd "$1" && ./gradlew -q "$2:help"' _ "$EXAMPLE/android" "$PLUGIN" > "$TMP/reject-missing.log" 2>&1; then
  fail "Gradle rejects the override without an explicit AAR path"
else
  grep -q "requires BEAROUND_NATIVE_AAR_PATH" "$TMP/reject-missing.log" \
    && pass "Gradle rejects the override without an explicit AAR path" \
    || fail "Gradle rejects the override without an explicit AAR path" "$TMP/reject-missing.log"
fi
if (cd "$EXAMPLE/ios" && BEAROUND_IOS_SDK_PATH="$TMP/old-ios" pod ipc spec "$ROOT/ios/bearound_flutter_sdk.podspec") > "$TMP/reject-pod.log" 2>&1; then
  fail "podspec rejects an iOS checkout without the app presence API"
else
  grep -q "does not contain the app presence API" "$TMP/reject-pod.log" \
    && pass "podspec rejects an iOS checkout without the app presence API" \
    || fail "podspec rejects an iOS checkout without the app presence API" "$TMP/reject-pod.log"
fi

echo "1..$((PASSED + FAILED))"
echo "# passed $PASSED, failed $FAILED"
[[ $FAILED -eq 0 ]]
