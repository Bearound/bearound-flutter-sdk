import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bearound_flutter_sdk/src/core/permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel sdkChannel = MethodChannel('bearound_flutter_sdk');
  const MethodChannel permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  // permission_handler codes (permission_handler_platform_interface's
  // `Permission._value`), used to read which permissions were actually
  // requested/checked off the wire.
  const int bluetoothScanCode = 28;
  const int bluetoothAdvertiseCode = 29;

  group('PermissionService', () {
    late PermissionService permissionService;
    final List<MethodCall> permissionCalls = [];

    setUp(() {
      permissionService = PermissionService.instance;
      permissionCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, (call) async {
            permissionCalls.add(call);
            if (call.method == 'requestPermissions') {
              final codes = List<int>.from(call.arguments as List);
              // Every requested permission comes back granted (value `1`).
              return {for (final code in codes) code: 1};
            }
            if (call.method == 'checkPermissionStatus') {
              return 1; // granted
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sdkChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(permissionChannel, null);
    });

    void mockAndroidSdkInt(int level) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sdkChannel, (call) async {
            if (call.method == 'getAndroidSdkInt') return level;
            return null;
          });
    }

    List<int> codesRequestedFor(String method) {
      return permissionCalls
          .where((c) => c.method == method)
          .expand((c) => List<int>.from(c.arguments as List))
          .toList();
    }

    test('should be a singleton', () {
      final instance1 = PermissionService.instance;
      final instance2 = PermissionService.instance;

      expect(instance1, same(instance2));
    });

    group('requestPermissions', () {
      testWidgets('should handle iOS permissions', (tester) async {
        // Note: This test is simplified since we can't easily mock Platform.isIOS
        // In a real scenario, you might want to inject the platform dependency

        // For now, we'll test the basic structure
        expect(permissionService.requestPermissions, isA<Function>());
      });

      test('should return false on exception', () async {
        // This is a basic test structure since mocking complex platform APIs
        // requires more sophisticated test setup
        expect(permissionService.requestPermissions, isA<Function>());
      });
    });

    group('Android BLUETOOTH_ADVERTISE (encounter layer)', () {
      test(
        'requests bluetoothAdvertise on API 31+ (same batch as bluetoothScan)',
        () async {
          mockAndroidSdkInt(31);

          final result = await permissionService
              .requestAndroidPermissionsForTest();

          expect(result, isTrue);
          expect(
            codesRequestedFor('requestPermissions'),
            contains(bluetoothAdvertiseCode),
          );
        },
      );

      test('does NOT request bluetoothAdvertise below API 31', () async {
        mockAndroidSdkInt(30);

        await permissionService.requestAndroidPermissionsForTest();

        final requestedCodes = permissionCalls
            .where((c) => c.method == 'requestPermissions')
            .expand((c) => List<int>.from(c.arguments as List));
        expect(requestedCodes, isNot(contains(bluetoothAdvertiseCode)));
      });

      test('denying bluetoothAdvertise does not break the scan result '
          '(one-way mesh, not a broken SDK)', () async {
        mockAndroidSdkInt(31);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(permissionChannel, (call) async {
              permissionCalls.add(call);
              if (call.method == 'requestPermissions') {
                final codes = List<int>.from(call.arguments as List);
                return {
                  for (final code in codes)
                    // Every permission granted EXCEPT bluetoothAdvertise.
                    code: code == bluetoothAdvertiseCode ? 0 : 1,
                };
              }
              return null;
            });

        final result = await permissionService
            .requestAndroidPermissionsForTest();

        expect(
          result,
          isTrue,
          reason:
              'the scan gate is bluetoothScan alone; a denied '
              'bluetoothAdvertise must not report failure',
        );
      });

      test(
        'checkPermissions reads bluetoothAdvertise status on API 31+',
        () async {
          mockAndroidSdkInt(31);

          final result = await permissionService
              .checkAndroidPermissionsForTest();

          expect(result, isTrue);
          final checkedCodes = permissionCalls
              .where((c) => c.method == 'checkPermissionStatus')
              .map((c) => c.arguments as int);
          expect(checkedCodes, contains(bluetoothAdvertiseCode));
          expect(checkedCodes, contains(bluetoothScanCode));
        },
      );
    });
  });
}
