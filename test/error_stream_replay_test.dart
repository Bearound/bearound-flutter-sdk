import 'package:bearound_flutter_sdk/bearound_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies that [BearoundFlutterSdk.errorStream] buffers errors emitted by the
/// native side *before* the first Dart listener and replays them to that
/// listener (the Car-Media-class bug: an error on the first `startScanning`
/// arriving before `listen()` used to be lost forever).
///
/// The error EventChannel state inside [BearoundFlutterSdk] is a process-wide
/// singleton (static), so this file drives it with a single ordered scenario.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String channelName = 'bearound_flutter_sdk/errors';
  const StandardMethodCodec codec = StandardMethodCodec();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // Sends an event down the EventChannel as if the native side emitted it.
  void emitError(Map<String, dynamic> payload) {
    messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope(payload),
      (_) {},
    );
  }

  test('errorStream replays pre-listen errors to the first listener', () async {
    // The EventChannel only starts delivering once it has been "listened" on
    // the platform side. Accessing the getter triggers the eager buffer
    // subscription, which sends the `listen` MethodCall — mock it as success.
    messenger.setMockMethodCallHandler(
      const MethodChannel(channelName, codec),
      (call) async => null,
    );

    // Access the stream once — this wires up the eager buffer subscription
    // BEFORE we attach an app-level listener.
    final stream = BearoundFlutterSdk.errorStream;

    // Native emits two errors while nobody is listening yet.
    emitError({'message': 'boot failure', 'details': 'no permission'});
    emitError({'message': 'scan failed'});

    // Give the microtask queue a turn so the eager listener buffers them.
    await Future<void>.delayed(Duration.zero);

    // Now the app attaches its first listener — it must receive the buffered
    // errors (in order) as replay.
    final received = <BearoundError>[];
    final sub = stream.listen(received.add);

    // Let replay flush.
    await Future<void>.delayed(Duration.zero);

    expect(
      received.map((e) => e.message).toList(),
      equals(['boot failure', 'scan failed']),
    );
    expect(received.first.details, equals('no permission'));

    await sub.cancel();
  });
}
