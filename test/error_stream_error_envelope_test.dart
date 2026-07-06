import 'dart:convert';

import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:bearound_flutter_sdk/src/telemetry/error_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// NEVER-CRASH doctrine (CHANGELOG 3.4.5, Fixed #2): an ERROR envelope on the
/// native error channel must not surface as an unhandled async error attributed
/// to the SDK inside the host app — the eager buffer subscription's `onError`
/// guard swallows it and reports it to telemetry (`context: errorStream`).
///
/// Kept in its own file: the error-channel state in [BearoundFlutterSdk] is a
/// process-wide static, and this scenario needs the eager subscription to be
/// the ONLY subscription (no app-level listener attached).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String channelName = 'bearound_flutter_sdk/errors';
  const StandardMethodCodec codec = StandardMethodCodec();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'channel error envelope: swallowed + reported, host never sees a throw',
    () async {
      final reporter = ErrorReporter.instance;
      reporter.resetForTest();
      final bodies = <String>[];
      reporter.transport = (body, token) async => bodies.add(body);

      messenger.setMockMethodCallHandler(
        const MethodChannel(channelName, codec),
        (call) async => null,
      );

      // The report's device snapshot probes permission_handler. Mock its
      // channel so the probes resolve deterministically within pumpEventQueue —
      // unmocked, the response only arrives after the test body (the report
      // is invoked from the platform-message context, not the test zone).
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter.baseflow.com/permissions/methods'),
        (call) async => 0,
      );

      // Arm the eager buffer subscription WITHOUT attaching an app listener.
      expect(BearoundFlutterSdk.errorStream, isA<Stream<BearoundError>>());

      // Native side emits an ERROR envelope (not an event). Without the onError
      // guard this becomes an unhandled async error and this test would fail.
      messenger.handlePlatformMessage(
        channelName,
        codec.encodeErrorEnvelope(code: 'NATIVE_ERR', message: 'scan blew up'),
        (_) {},
      );

      await pumpEventQueue();

      expect(bodies, hasLength(1));
      final payload = jsonDecode(bodies.first) as Map<String, dynamic>;
      expect(
        (payload['error'] as Map<String, dynamic>)['context'],
        equals('errorStream'),
      );

      reporter.resetForTest();
    },
  );
}
