import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ratchet: the SDK and its examples must never open the user's settings for
/// them — reporting permission state is fine, navigating there is not.
/// Reads `lib/` and `example/lib/` as text.
void main() {
  final sources = <File>[
    ...Directory('lib').listSync(recursive: true).whereType<File>(),
    ...Directory('example/lib').listSync(recursive: true).whereType<File>(),
  ].where((f) => f.path.endsWith('.dart')).toList();

  test('sources exist to scan', () {
    expect(sources, isNotEmpty);
  });

  test('nothing navigates the user out to the system settings', () {
    final offenders = <String>[];
    for (final file in sources) {
      final code = file.readAsStringSync();
      for (final marker in const [
        'openAppSettings(',
        'AppSettings.',
        'UIApplication.shared.open',
        'ACTION_APPLICATION_DETAILS_SETTINGS',
      ]) {
        if (code.contains(marker)) {
          offenders.add('${file.path}: $marker');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'The SDK and its examples must report permission state, never open '
          'Settings for the user. Show the state and the cost instead.',
    );
  });

  test('background location is never requested without an explicit opt-in', () {
    // `Permission.locationAlways.request()` may exist, but only behind an
    // `include*` flag the caller had to turn on.
    final opener = RegExp(r'Permission\.locationAlways\.request\(\)');
    final gated = RegExp(
      r'if \([A-Za-z]*[Ii]nclude[A-Za-z]* &&|'
      r'if \([A-Za-z]*[Ii]nclude[A-Za-z]*\)',
    );

    for (final file in sources) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!opener.hasMatch(lines[i])) continue;
        // The guard is the nearest preceding `if`, within 3 lines.
        final window = lines.sublist((i - 3).clamp(0, i), i + 1).join('\n');
        expect(
          gated.hasMatch(window),
          isTrue,
          reason:
              '${file.path}:${i + 1} requests background location without an '
              'explicit include* opt-in. Background location must be asked '
              'for only when the caller deliberately asked for it.',
        );
      }
    }
  });
}
