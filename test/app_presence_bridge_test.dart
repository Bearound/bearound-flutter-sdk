import 'dart:async';

import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the app presence bridge through mocked platform channels: the method
/// channel answers configure / getter calls and the event channel is fed as if the
/// native SDK emitted snapshots.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('bearound_flutter_sdk');
  const eventChannelName = 'bearound_flutter_sdk/app_presence';
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> methodCalls;
  late List<String> eventChannelCalls;
  late Future<Object?> Function(MethodCall call) onMethodCall;

  Map<String, dynamic> snapshot(String id, {bool cached = false}) =>
      <String, dynamic>{
        'schemaVersion': 1,
        'snapshotId': id,
        'configurationFingerprint': 'a' * 64,
        'checkedAt': '2026-10-09T12:00:00.000Z',
        'cached': cached,
        'results': <Map<String, dynamic>>[
          {
            'targetId': 'fixture',
            'state': 'unknown',
            'present': null,
            'reason': 'not_declared',
            'checkedAt': '2026-10-09T11:59:59.999Z',
            'detectionMethod': 'ios_url_scheme',
          },
        ],
      };

  void emit(Object? payload) {
    messenger.handlePlatformMessage(
      eventChannelName,
      codec.encodeSuccessEnvelope(payload),
      (_) {},
    );
  }

  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    methodCalls = <MethodCall>[];
    eventChannelCalls = <String>[];
    onMethodCall = (_) async => null;
    messenger.setMockMethodCallHandler(methodChannel, (call) {
      methodCalls.add(call);
      return onMethodCall(call);
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel(eventChannelName, codec),
      (call) async {
        eventChannelCalls.add(call.method);
        return null;
      },
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel(eventChannelName, codec),
      null,
    );
  });

  group('configureAppPresence', () {
    test('forwards the configuration as a JSON object', () async {
      await BearoundFlutterSdk.configureAppPresence(
        const AppPresenceConfiguration(
          enabled: true,
          targets: [AppPresenceTarget(id: 'fixture', iosScheme: 'fixture-app')],
        ),
      );

      expect(methodCalls.single.method, 'configureAppPresence');
      expect(methodCalls.single.arguments, {
        'enabled': true,
        'targets': [
          {
            'id': 'fixture',
            'iosScheme': 'fixture-app',
            'androidPackageName': null,
          },
        ],
      });
    });

    test(
      'rejects with the stable code when the native SDK refuses it',
      () async {
        onMethodCall = (_) async => throw PlatformException(
          code: 'app_presence_invalid_configuration',
          message: 'duplicate target id',
        );

        await expectLater(
          BearoundFlutterSdk.configureAppPresence(
            const AppPresenceConfiguration(enabled: true),
          ),
          throwsA(
            isA<AppPresenceConfigurationException>()
                .having(
                  (e) => e.code,
                  'code',
                  'app_presence_invalid_configuration',
                )
                .having((e) => e.message, 'message', 'duplicate target id'),
          ),
        );
      },
    );

    test('rethrows unrelated channel errors unchanged', () async {
      onMethodCall = (_) async =>
          throw PlatformException(code: 'SDK_UNAVAILABLE');

      await expectLater(
        BearoundFlutterSdk.configureAppPresence(
          const AppPresenceConfiguration(),
        ),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'SDK_UNAVAILABLE',
          ),
        ),
      );
    });
  });

  group('getLastAppPresenceSnapshot', () {
    test('returns null when there is no compatible snapshot', () async {
      expect(await BearoundFlutterSdk.getLastAppPresenceSnapshot(), isNull);
    });

    test(
      'returns the cached snapshot with its original id and times',
      () async {
        onMethodCall = (_) async => snapshot('round-1', cached: true);

        final result = await BearoundFlutterSdk.getLastAppPresenceSnapshot();

        expect(result!.snapshotId, 'round-1');
        expect(result.cached, isTrue);
        expect(result.checkedAt, DateTime.utc(2026, 10, 9, 12));
        expect(result.results.single.present, isNull);
        expect(methodCalls.map((c) => c.method), [
          'getLastAppPresenceSnapshot',
        ]);
      },
    );
  });

  group('appPresenceStream', () {
    test('a late subscription gets the cached replay without a scan', () async {
      onMethodCall = (_) async => snapshot('round-1', cached: true);

      final received = <AppPresenceSnapshot>[];
      final sub = BearoundFlutterSdk.appPresenceStream.listen(received.add);
      await flush();

      expect(received.map((s) => s.snapshotId), ['round-1']);
      expect(received.single.cached, isTrue);
      expect(methodCalls.map((c) => c.method), ['getLastAppPresenceSnapshot']);
      await sub.cancel();
    });

    test('registers for live events before asking for the replay', () async {
      final sub = BearoundFlutterSdk.appPresenceStream.listen((_) {});
      await flush();

      expect(eventChannelCalls.first, 'listen');
      expect(methodCalls.single.method, 'getLastAppPresenceSnapshot');
      await sub.cancel();
    });

    test(
      'delivers a snapshotId once per subscription, new rounds always',
      () async {
        onMethodCall = (_) async => snapshot('round-1', cached: true);

        final received = <AppPresenceSnapshot>[];
        final sub = BearoundFlutterSdk.appPresenceStream.listen(received.add);
        await flush();

        // Native replay of the same round (listener reassignment), then a new round
        // with identical results.
        emit(snapshot('round-1', cached: true));
        emit(snapshot('round-2'));
        await flush();

        expect(received.map((s) => s.snapshotId), ['round-1', 'round-2']);
        expect(received.map((s) => s.cached), [true, false]);
        await sub.cancel();
      },
    );

    test('drops a replay that arrives after a live round', () async {
      final replay = Completer<Object?>();
      onMethodCall = (_) => replay.future;

      final received = <AppPresenceSnapshot>[];
      final sub = BearoundFlutterSdk.appPresenceStream.listen(received.add);
      await flush();

      emit(snapshot('round-2'));
      await flush();
      replay.complete(snapshot('round-1', cached: true));
      await flush();

      expect(received.map((s) => s.snapshotId), ['round-2']);
      await sub.cancel();
    });

    test('every new subscription gets its own replay', () async {
      onMethodCall = (_) async => snapshot('round-1', cached: true);

      final first = <String>[];
      final second = <String>[];
      final subA = BearoundFlutterSdk.appPresenceStream.listen(
        (s) => first.add(s.snapshotId),
      );
      await flush();
      final subB = BearoundFlutterSdk.appPresenceStream.listen(
        (s) => second.add(s.snapshotId),
      );
      await flush();

      expect(first, ['round-1']);
      expect(second, ['round-1']);
      await subA.cancel();
      await subB.cancel();
    });

    test(
      'cancelling removes the subscription and the native listener',
      () async {
        final received = <String>[];
        final sub = BearoundFlutterSdk.appPresenceStream.listen(
          (s) => received.add(s.snapshotId),
        );
        await flush();
        await sub.cancel();
        await flush();

        emit(snapshot('round-3'));
        await flush();

        expect(received, isEmpty);
        expect(eventChannelCalls, ['listen', 'cancel']);
      },
    );

    test(
      'a malformed event or a channel error does not stop later rounds',
      () async {
        final received = <String>[];
        final errors = <Object>[];
        final sub = BearoundFlutterSdk.appPresenceStream.listen(
          (s) => received.add(s.snapshotId),
          onError: errors.add,
        );
        await flush();

        emit(<String, dynamic>{'schemaVersion': 1, 'snapshotId': 'broken'});
        emit(snapshot('round-4')..['results'][0]['state'] = 'maybe');
        messenger.handlePlatformMessage(
          eventChannelName,
          codec.encodeErrorEnvelope(code: 'native', message: 'dispatch failed'),
          (_) {},
        );
        emit(snapshot('round-5'));
        await flush();

        expect(received, ['round-5']);
        expect(errors, isEmpty);
        await sub.cancel();
      },
    );

    test('a failed replay keeps the live subscription', () async {
      onMethodCall = (_) async =>
          throw PlatformException(code: 'SDK_UNAVAILABLE');

      final received = <String>[];
      final sub = BearoundFlutterSdk.appPresenceStream.listen(
        (s) => received.add(s.snapshotId),
      );
      await flush();
      emit(snapshot('round-6'));
      await flush();

      expect(received, ['round-6']);
      await sub.cancel();
    });
  });
}
