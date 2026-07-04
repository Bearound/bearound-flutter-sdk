import 'dart:convert';

import 'package:bearound_flutter_sdk/src/telemetry/error_reporter.dart';
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
