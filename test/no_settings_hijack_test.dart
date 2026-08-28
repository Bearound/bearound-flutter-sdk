import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One-way ratchet for a rule the owner made explicit after the Android SDK
/// shipped an example that navigated to the system Settings on its own:
///
/// > the SDK and its examples must never open the user's settings for them.
/// > Reporting the state is fine; hijacking the navigation is not.
///
/// The cost of breaking it is not cosmetic. The user grants the permissions,
/// the app opens, and it immediately throws them onto the OS permission screen
/// to chase ACCESS_BACKGROUND_LOCATION — which, from Android 11 on, has no
/// dialog and can only be granted there. It reads as a crash into Settings,
/// and it happens before the app has shown anything.
///
/// This test reads the sources as text, so it holds for `lib/` (the published
/// SDK) and `example/lib/` (what integrators copy) alike.
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
    // `Permission.locationAlways.request()` is allowed to exist — but only
    // behind a flag the caller had to turn on: `includeBackgroundLocation`
    // in the SDK (host opt-in, Play prominent-disclosure ordering) and
    // `includeAlwaysUpgrade` in the example (a labelled button, not boot).
    final opener = RegExp(r'Permission\.locationAlways\.request\(\)');
    final gated = RegExp(
      r'if \([A-Za-z]*[Ii]nclude[A-Za-z]* &&|'
      r'if \([A-Za-z]*[Ii]nclude[A-Za-z]*\)',
    );

    for (final file in sources) {
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!opener.hasMatch(lines[i])) continue;
        // The guard is the nearest preceding `if` — within 3 lines, since
        // these are always written as a one- or two-line conditional.
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
