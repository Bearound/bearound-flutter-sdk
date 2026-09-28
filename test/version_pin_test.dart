import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard: the plugin version and the native SDK pins stay aligned.
/// Reads `pubspec.yaml`, the podspec, `android/build.gradle` and the telemetry
/// version constant as text, the same files the release workflow checks.
void main() {
  String read(String path) => File(path).readAsStringSync();

  // Throws at load time, failing the whole file, when a pin cannot be parsed.
  String match(String source, RegExp pattern, String label) {
    final m = pattern.firstMatch(source);
    if (m == null) throw StateError('Could not find the $label pin.');
    return m.group(1)!;
  }

  final pubspecVersion = match(
    read('pubspec.yaml'),
    RegExp(r'^version:\s*(\d+\.\d+\.\d+)\s*$', multiLine: true),
    'pubspec version',
  );
  final telemetryVersion = match(
    read('lib/src/telemetry/error_reporter.dart'),
    RegExp(r"_sdkVersion = '([^']+)'"),
    'telemetry _sdkVersion',
  );
  final iosPin = match(
    read('ios/bearound_flutter_sdk.podspec'),
    RegExp(
      r"""s\.dependency\s+['"]BearoundSDK['"]\s*,\s*['"](\d+\.\d+\.\d+)['"]""",
    ),
    'iOS BearoundSDK',
  );
  final androidCoordinate = RegExp(
    r"bearound-android-sdk:(v?)(\d+\.\d+\.\d+)'",
  ).firstMatch(read('android/build.gradle'));

  String line(String version) => version.split('.').take(2).join('.');
  String major(String version) => version.split('.').first;

  test('telemetry version mirrors pubspec', () {
    expect(telemetryVersion, pubspecVersion);
  });

  test('Android pin is the JitPack tag with the v prefix', () {
    expect(androidCoordinate, isNotNull);
    expect(androidCoordinate!.group(1), 'v');
  });

  test('iOS and Android pins sit on the same native line', () {
    expect(line(androidCoordinate!.group(2)!), line(iosPin));
  });

  test('plugin major mirrors the native major', () {
    expect(major(pubspecVersion), major(iosPin));
  });

  test('pins are at least the native 3.12.0 that draws rich push', () {
    bool atLeast3_12(String version) {
      final parts = version.split('.').map(int.parse).toList();
      return parts[0] > 3 || (parts[0] == 3 && parts[1] >= 12);
    }

    expect(atLeast3_12(iosPin), isTrue, reason: 'iOS pin: $iosPin');
    expect(
      atLeast3_12(androidCoordinate!.group(2)!),
      isTrue,
      reason: 'Android pin: ${androidCoordinate.group(2)}',
    );
  });
}
