import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:bearound_flutter_sdk/src/telemetry/error_reporter.dart';
import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
import 'package:flutter_test/flutter_test.dart';

/// A synthetic stack trace whose text contains a `package:bearound_flutter_sdk`
/// frame — i.e. an error that originated in OUR library.
StackTrace _sdkStack() => StackTrace.fromString(
  '#0      _scan (package:bearound_flutter_sdk/src/core/scanner.dart:42:7)\n'
  '#1      main (package:example/main.dart:10:3)',
);

/// A stack trace with NO SDK frames — an error from the host app / a third
/// party. Must never be reported.
StackTrace _hostStack() => StackTrace.fromString(
  '#0      _onTap (package:example/home.dart:88:9)\n'
  '#1      GestureRecognizer.invoke (package:flutter/src/gestures.dart:120:5)',
);

/// A stack trace whose ONLY SDK frame is this telemetry file itself — a
/// reporter-internal error. Must be excluded (never classified as SDK error).
StackTrace _telemetryOnlyStack() => StackTrace.fromString(
  '#0      ErrorReporter._report '
  '(package:bearound_flutter_sdk/src/telemetry/error_reporter.dart:150:7)',
);

/// The critical leak case: a HOST error thrown inside one of our callbacks. The
/// host frame is on top (the culprit), our frame is below (we merely invoked the
/// callback). Must NEVER be reported — it is the host app's bug.
StackTrace _hostViaSdkCallbackStack() => StackTrace.fromString(
  '#0      _onBeacons (package:example/home.dart:88:9)\n'
  '#1      BearoundFlutterSdk._emit '
  '(package:bearound_flutter_sdk/src/events.dart:30:5)\n'
  '#2      main (package:example/main.dart:10:3)',
);

/// The real-world async shape: runtime frames (`<asynchronous suspension>`,
/// `dart:async`, `package:flutter/`) ABOVE the first application frame — which
/// is ours. This is how most production errors reach PlatformDispatcher.onError.
StackTrace _sdkUnderRuntimeStack() => StackTrace.fromString(
  '<asynchronous suspension>\n'
  '#0      _rootRunUnary (dart:async/zone.dart:1407:47)\n'
  '#1      _FutureListener.handleError (dart:async/future_impl.dart:152:20)\n'
  '#2      GestureRecognizer.invokeCallback '
  '(package:flutter/src/gestures/recognizer.dart:275:24)\n'
  '#3      _scan (package:bearound_flutter_sdk/src/core/scanner.dart:42:7)\n'
  '#4      main (package:example/main.dart:10:3)',
);

/// Same runtime prelude, but the first application frame is the HOST's — the
/// runtime skip must not leak past the host frame into our frame below it.
StackTrace _hostUnderRuntimeStack() => StackTrace.fromString(
  '<asynchronous suspension>\n'
  '#0      _rootRunUnary (dart:async/zone.dart:1407:47)\n'
  '#1      GestureRecognizer.invokeCallback '
  '(package:flutter/src/gestures/recognizer.dart:275:24)\n'
  '#2      _onTap (package:example/home.dart:88:9)\n'
  '#3      BearoundFlutterSdk._emit '
  '(package:bearound_flutter_sdk/src/events.dart:30:5)',
);

/// Adversarial marker collision: a HOST file merely NAMED after the SDK
/// (`bearound_flutter_sdk_helper.dart` — a common way to name an integration
/// wrapper). Its errors belong to the host and must never reach our ingest.
StackTrace _hostFileNamedAfterSdkStack() => StackTrace.fromString(
  '#0      MyWrapper.scan '
  '(package:host_app/bearound_flutter_sdk_helper.dart:12:5)\n'
  '#1      main (package:host_app/main.dart:10:3)',
);

/// Adversarial marker collision on the telemetry-file skip: a HOST file named
/// `error_reporter.dart` on top of one of OUR frames. A bare-filename skip
/// would jump the host frame and misattribute the error to the SDK frame below.
StackTrace _hostErrorReporterFileStack() => StackTrace.fromString(
  '#0      HostTelemetry.report '
  '(package:host_app/src/error_reporter.dart:33:9)\n'
  '#1      BearoundFlutterSdk._emit '
  '(package:bearound_flutter_sdk/src/events.dart:30:5)',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reporter = ErrorReporter.instance;

  setUp(() => reporter.resetForTest());
  tearDown(() => reporter.resetForTest());

  group('package filter', () {
    test('reports an error whose stack contains an SDK frame', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'StateError',
        message: 'Bad state',
        stack: _sdkStack(),
        context: 'uncaught',
      );

      expect(reported, isTrue);
      expect(bodies, hasLength(1));

      final payload = jsonDecode(bodies.first) as Map<String, dynamic>;
      final error = payload['error'] as Map<String, dynamic>;
      expect(error['type'], equals('StateError'));
      expect(error['context'], equals('uncaught'));
      expect((payload['sdk'] as Map)['platform'], equals('flutter'));
    });

    test('ignores an error from the host app (no SDK frame)', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'Exception',
        message: 'host blew up',
        stack: _hostStack(),
        context: 'uncaught',
      );

      expect(reported, isFalse);
      expect(bodies, isEmpty);
    });

    test('ignores a reporter-internal error (telemetry file only)', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'Exception',
        message: 'telemetry blew up',
        stack: _telemetryOnlyStack(),
        context: 'async',
      );

      expect(reported, isFalse);
      expect(bodies, isEmpty);
    });

    test('ignores a HOST error thrown inside an SDK callback', () async {
      // The origin (top application frame) is the host — our frame is only below
      // it because we invoked the callback. Must never be captured.
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'Exception',
        message: 'host callback blew up',
        stack: _hostViaSdkCallbackStack(),
        context: 'uncaught',
      );

      expect(reported, isFalse);
      expect(bodies, isEmpty);
    });

    test(
      'skips runtime frames above an SDK origin (async production shape)',
      () async {
        final bodies = <String>[];
        reporter.transport = (body, token) async => bodies.add(body);

        final reported = await reporter.reportForTest(
          type: 'StateError',
          message: 'async sdk failure',
          stack: _sdkUnderRuntimeStack(),
          context: 'async',
        );

        expect(reported, isTrue);
        expect(bodies, hasLength(1));
      },
    );

    test(
      'runtime skip stops at the first HOST frame (no leak-through)',
      () async {
        final bodies = <String>[];
        reporter.transport = (body, token) async => bodies.add(body);

        final reported = await reporter.reportForTest(
          type: 'StateError',
          message: 'async host failure',
          stack: _hostUnderRuntimeStack(),
          context: 'async',
        );

        expect(reported, isFalse);
        expect(bodies, isEmpty);
      },
    );

    test('ignores a HOST file merely named after the SDK package', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'Exception',
        message: 'host wrapper blew up',
        stack: _hostFileNamedAfterSdkStack(),
        context: 'uncaught',
      );

      expect(reported, isFalse);
      expect(bodies, isEmpty);
    });

    test('a HOST error_reporter.dart is not skipped as ours', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final reported = await reporter.reportForTest(
        type: 'Exception',
        message: 'host telemetry blew up',
        stack: _hostErrorReporterFileStack(),
        context: 'uncaught',
      );

      expect(reported, isFalse);
      expect(bodies, isEmpty);
    });
  });

  group('reportCaught', () {
    test(
      'null stack completes and delivers with an empty stackTrace',
      () async {
        final bodies = <String>[];
        reporter.transport = (body, token) async => bodies.add(body);

        expect(
          () => reporter.reportCaught(
            StateError('internal'),
            null,
            context: 'getPersistedLog',
          ),
          returnsNormally,
        );
        await pumpEventQueue();

        expect(bodies, hasLength(1));
        final payload = jsonDecode(bodies.first) as Map<String, dynamic>;
        final error = payload['error'] as Map<String, dynamic>;
        expect(error['stackTrace'], equals(''));
        expect(error['context'], equals('getPersistedLog'));
      },
    );

    test('bypasses the origin filter — the call site proves ownership', () async {
      // reportCaught is only reachable from inside our own plumbing, so it must
      // deliver even when the stack has no SDK frame (e.g. a host-side stack
      // captured by our internal EventChannel onError guard).
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      reporter.reportCaught(
        StateError('caught in plumbing'),
        _hostStack(),
        context: 'errorStream',
      );
      await pumpEventQueue();

      expect(bodies, hasLength(1));
    });
  });

  group('rate limit', () {
    test('caps at 20 reports/hour and the window slides', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);
      final base = DateTime(2026, 1, 1, 12);

      // 21 distinct errors (distinct type → distinct hash, so dedupe never
      // gates) at the same instant — the crash-loop shape this limit protects
      // the ingest against.
      for (var i = 0; i < 21; i++) {
        await reporter.reportForTest(
          type: 'StateError$i',
          message: 'x',
          stack: _sdkStack(),
          context: 'uncaught',
          now: base,
        );
      }
      expect(bodies, hasLength(20));

      // 61 minutes later the window has slid — delivery resumes.
      await reporter.reportForTest(
        type: 'StateError21',
        message: 'x',
        stack: _sdkStack(),
        context: 'uncaught',
        now: base.add(const Duration(minutes: 61)),
      );
      expect(bodies, hasLength(21));
    });
  });

  group('install chain (global handlers)', () {
    test(
      'PlatformDispatcher.onError: previous handler always chained, its return '
      'honored, only SDK-origin errors reported',
      () async {
        final bodies = <String>[];
        reporter.transport = (body, token) async => bodies.add(body);

        final originalDispatcher = PlatformDispatcher.instance.onError;
        final originalFlutterOnError = FlutterError.onError;
        var previousCalls = 0;
        PlatformDispatcher.instance.onError = (error, stack) {
          previousCalls++;
          return true; // e.g. Crashlytics: "handled".
        };

        reporter.install('token');
        final hook = PlatformDispatcher.instance.onError!;

        // Host-origin error: chained + return value honored, nothing reported.
        expect(hook(StateError('host'), _hostStack()), isTrue);
        expect(previousCalls, 1);
        await pumpEventQueue();
        expect(bodies, isEmpty);

        // SDK-origin error: reported AND still chained with the same contract.
        expect(hook(StateError('sdk'), _sdkStack()), isTrue);
        expect(previousCalls, 2);
        await pumpEventQueue();
        expect(bodies, hasLength(1));

        reporter.uninstallForTest();
        PlatformDispatcher.instance.onError = originalDispatcher;
        FlutterError.onError = originalFlutterOnError;
      },
    );

    test('a THROWING previous PlatformDispatcher handler is contained', () async {
      final originalDispatcher = PlatformDispatcher.instance.onError;
      final originalFlutterOnError = FlutterError.onError;
      PlatformDispatcher.instance.onError = (error, stack) =>
          throw StateError('host handler bug');

      reporter.install('token');
      final hook = PlatformDispatcher.instance.onError!;

      // Must not throw through our hook; falls back to `false` (do not consume).
      expect(hook(StateError('x'), _hostStack()), isFalse);

      reporter.uninstallForTest();
      PlatformDispatcher.instance.onError = originalDispatcher;
      FlutterError.onError = originalFlutterOnError;
    });

    test('FlutterError.onError: previous handler always invoked (even for host '
        'errors that are not reported)', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final originalDispatcher = PlatformDispatcher.instance.onError;
      final originalFlutterOnError = FlutterError.onError;
      final delegated = <FlutterErrorDetails>[];
      FlutterError.onError = delegated.add;

      reporter.install('token');

      final hostDetails = FlutterErrorDetails(
        exception: StateError('host'),
        stack: _hostStack(),
      );
      final sdkDetails = FlutterErrorDetails(
        exception: StateError('sdk'),
        stack: _sdkStack(),
      );

      FlutterError.onError!(hostDetails);
      FlutterError.onError!(sdkDetails);
      await pumpEventQueue();

      // BOTH delegated (host flow untouched); only the SDK one reported.
      expect(delegated, hasLength(2));
      expect(bodies, hasLength(1));

      reporter.uninstallForTest();
      PlatformDispatcher.instance.onError = originalDispatcher;
      FlutterError.onError = originalFlutterOnError;
    });
  });

  group('dedupe', () {
    test('suppresses an identical error within the dedupe window', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final base = DateTime(2026, 1, 1, 12);
      final stack = _sdkStack();

      await reporter.reportForTest(
        type: 'StateError',
        message: 'x',
        stack: stack,
        context: 'uncaught',
        now: base,
      );
      // Same type|context|first-line, 1 minute later — within the 5 min window.
      await reporter.reportForTest(
        type: 'StateError',
        message: 'x',
        stack: stack,
        context: 'uncaught',
        now: base.add(const Duration(minutes: 1)),
      );

      expect(bodies, hasLength(1));
    });

    test('allows the same error again after the dedupe window', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      final base = DateTime(2026, 1, 1, 12);
      final stack = _sdkStack();

      await reporter.reportForTest(
        type: 'StateError',
        message: 'x',
        stack: stack,
        context: 'uncaught',
        now: base,
      );
      await reporter.reportForTest(
        type: 'StateError',
        message: 'x',
        stack: stack,
        context: 'uncaught',
        now: base.add(const Duration(minutes: 6)),
      );

      expect(bodies, hasLength(2));
    });
  });

  group('transport isolation', () {
    test('a throwing transport does not surface to the caller', () async {
      reporter.transport = (body, token) async =>
          throw const SocketExceptionStub();

      // Must complete normally — the golden rule is that reporting never throws.
      await expectLater(
        reporter.reportForTest(
          type: 'StateError',
          message: 'x',
          stack: _sdkStack(),
          context: 'uncaught',
        ),
        completion(isTrue),
      );
    });

    test('disabled reporter never delivers', () async {
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);
      reporter.setEnabled(false);

      final reported = await reporter.reportForTest(
        type: 'StateError',
        message: 'x',
        stack: _sdkStack(),
        context: 'uncaught',
      );

      // Passed the package filter, but the disabled gate drops it silently.
      expect(reported, isTrue);
      expect(bodies, isEmpty);
    });
  });
}

/// Minimal throwing stand-in — avoids importing dart:io just for a test double.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketExceptionStub: connection failed';
}
