# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.3.5] - 2026-02-19

### Changed

- **Native SDKs Updated to v2.3.5**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.3.5`
  - iOS: `BearoundSDK ~> 2.3.5`
- **Documentation**: Updated README to reflect native SDK v2.3.5 alignment and package version.

---

## [2.3.2] - 2026-02-19

### Changed

- **Native SDKs Updated to v2.3.2**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.3.2`
  - iOS: `BearoundSDK ~> 2.3.2`
- **Documentation**: Updated README to reflect native SDK v2.3.2 alignment and package version.

---

## [2.3.1] - 2026-02-18

### Changed

- **Native SDKs Updated**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.3.0`
  - iOS: `BearoundSDK ~> 2.3.0`

### Added

- **Bluetooth-only (BT) proximity fallback**: New `BeaconProximity.bt` value for beacons detected via Bluetooth scanning only, without CoreLocation/distance estimation.

### Technical Details

- **Native SDK v2.3.0 Changes**:
  - Added BT proximity for bluetooth-only fallback detection
  - Improved beacon structure with discovery source tracking

---

## [2.2.3] - 2026-01-22

### Changed

- **Native SDKs Updated**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.2.2`
  - iOS: `BearoundSDK ~> 2.2.2`

### Fixed

- **iOS Podspec Version Sync**: Fixed podspec version that was out of sync with the package version.

### Technical Details

- **Native SDK v2.2.2 Changes**:
  - Removed 1-second foreground scan interval option (minimum is now 5 seconds)
  - 5-second foreground scan interval now uses continuous scanning (no pause between scans)
  - Beacons are no longer cleared from internal state after being sent to the API

## [2.2.2] - 2026-01-21

### Changed

- **iOS Permission Handling**: Permissions are now requested via native Swift code using `CLLocationManager.requestAlwaysAuthorization()`, matching the behavior of the iOS native SDK and React Native SDK. This eliminates the blue GPS indicator that appeared when using the `location` Flutter package.

### Fixed

- **iOS: Blue GPS indicator no longer appears**: Removed dependency on the `location` Flutter package for iOS. Permissions are now handled natively via MethodChannel, which prevents the continuous location updates that caused the blue GPS indicator to appear.

- **iOS: Permission flow aligned with native SDKs**: The permission request now goes directly to "Always" authorization (like React Native and iOS native SDKs) instead of first asking for "When In Use" and then upgrading.

### Removed

- **Removed `location` package dependency**: The `location` package is no longer used. iOS permissions are handled via native Swift code, and Android permissions continue to use `permission_handler`.

### Technical Details

- **iOS Plugin (`BearoundFlutterSdkPlugin.swift`)**:
  - Added `CLLocationManagerDelegate` conformance
  - Added `requestPermissions` method that calls `requestAlwaysAuthorization()` directly
  - Added `checkPermissions` method to verify current authorization status
  - Both methods mirror the React Native SDK's `RNBearoundBridge.swift` implementation

- **Permission Service (`permission_service.dart`)**:
  - iOS: Now uses `MethodChannel` to call native Swift permission methods
  - Android: Continues using `permission_handler` package
  - Added `checkPermissions()` method to the public API

## [2.2.1] - 2026-01-20

### ⚠️ Breaking Changes

- **Removed `syncStream`**: The countdown updates (`secondsUntilNextSync`, `isRanging`) have been removed to save battery. The native iOS SDK removed this callback, and we're aligning all SDKs.
- **Removed `SyncStatus` model**: No longer needed without `syncStream`.

### Fixed

- **iOS/Android: Auto-restored scan not respecting configuration**: Fixed critical bug where if the SDK auto-restored scanning from a previous session, it would continue with the old configuration (continuous scan) instead of using the new configuration. The plugin now detects if SDK was already scanning during `configure()`, stops it, applies the new configuration, and restarts with correct periodic scan settings.
- **Android: No beacons appearing**: Fixed critical bug where the listener was not being properly set in `configure()` and `startScanning()` methods. The Android plugin now correctly redefines the listener to ensure beacon events are received even when the listener was previously overwritten by the Application class.
- **Android: Example app beacon detection blocked**: Removed `android:usesPermissionFlags="neverForLocation"` from `BLUETOOTH_SCAN` permission in example app manifest. This flag was blocking iBeacon detection since beacons require location services.
- **iOS: App state synchronization**: Added workaround to force the SDK to recognize the correct foreground state by posting `willEnterForegroundNotification` when starting scan in active state. This addresses a potential race condition where the BeaconManager might have been initialized with incorrect foreground state.
- **Flutter Example: Duplicate scan initialization**: Removed duplicate `configure()` call in `_startScan()` method that was causing the scan to restart twice in rapid succession.

### Changed

- **Native SDKs Updated**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.2.1`
  - iOS: `BearoundSDK ~> 2.2.1`

### Technical Details

- **Both iOS and Android Plugins**: 
  - Added logic in `configure()` to detect if SDK was already scanning (auto-restored)
  - If SDK was scanning, stops it, applies new config, and restarts with correct settings
  - This ensures periodic scan configuration is always applied correctly
  - Cleaned up diagnostic logs - keeping only essential error logging

- **Android Plugin**: 
  - Re-assigns listener in both `configure()` and `startScanning()` methods
  - This ensures Flutter plugin always receives callbacks even if Application class overwrites listener
  - Maintains error logging for debugging
  
- **iOS Plugin**:
  - Posts `willEnterForegroundNotification` when starting scan in active state
  - This forces SDK to correctly recognize foreground state and apply periodic scan configuration
  - Syncs `isActiveScan` with SDK state to handle auto-restored scanning

## [2.2.0] - 2026-01-20

### ⚠️ Breaking Changes

**Simplified Configuration**: Bluetooth metadata and periodic scanning are now automatic. The `enableBluetoothScanning` and `enablePeriodicScanning` parameters have been removed from the `configure()` method.

### Added

- **NEW Streams for Better Control**:
  - `syncLifecycleStream`: Notifies when sync operations start and complete
    - `onSyncStarted(beaconCount)`: Called before starting a sync
    - `onSyncCompleted(beaconCount, success, error)`: Called after sync completes
  - `backgroundDetectionStream`: Notifies when beacons are detected in background
    - `onBeaconDetectedInBackground(beaconCount)`: Called when beacons detected while app is in background

- **New Models**:
  - `SyncLifecycleEvent`: Represents sync lifecycle events with type, beaconCount, success, and error fields
  - `BackgroundDetectionEvent`: Represents background detection events with beaconCount

### Changed

- **Automatic Features**: 
  - Bluetooth metadata collection is now always enabled (no need to configure)
  - Periodic scanning is automatic:
    - Foreground: Enabled (saves battery)
    - Background: Continuous (maximum detection)

- **Native SDKs Updated**:
  - Android: `com.github.Bearound:bearound-android-sdk:v2.2.1`
  - iOS: `BearoundSDK ~> 2.2.1`

- **Platform Improvements**:
  - Android: Renamed `BeAroundSDKDelegate` to `BeAroundSDKListener` (Android naming convention)
  - Android: Changed callback prefix from `did*` to `on*` (e.g., `didUpdateBeacons` → `onBeaconsUpdated`)
  - iOS: Added new callbacks while maintaining `did*` prefix (iOS convention)

### Removed

- `enableBluetoothScanning` parameter from `configure()` method (now automatic)
- `enablePeriodicScanning` parameter from `configure()` method (now automatic)
- `setBluetoothScanning()` method (no longer needed)

### Migration

**Before (v2.1.0):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'your-token',
  enableBluetoothScanning: true,
  enablePeriodicScanning: true,
);
```

**After (v2.2.0):**
```dart
// Simpler configuration
await BearoundFlutterSdk.configure(
  businessToken: 'your-token',
  // Bluetooth metadata and periodic scanning are automatic
);

// NEW: Listen to sync lifecycle
BearoundFlutterSdk.syncLifecycleStream.listen((event) {
  if (event.isStarted) {
    print('📤 Sync started: ${event.beaconCount} beacons');
  } else if (event.isCompleted) {
    if (event.success == true) {
      print('✅ Sync success: ${event.beaconCount} beacons sent');
    } else {
      print('❌ Sync failed: ${event.error}');
    }
  }
});

// NEW: Listen to background detections
BearoundFlutterSdk.backgroundDetectionStream.listen((event) {
  print('🌙 Background: ${event.beaconCount} beacons detected');
});
```

### Technical Details

- Improved code deduplication in native Android SDK
- Better async handling for device info collection
- iOS SDK updated with new callback structure
- All callbacks now have debug logging support

---

## [2.1.0] - 2026-01-13

### ⚠️ Breaking Changes

**Configurable Scan Intervals**: SDK now supports separate foreground and background scan intervals with configurable retry queue.

### Added

- **Configurable Scan Intervals**: New enums for fine-grained control over scan behavior
  - `ForegroundScanInterval`: Configure foreground scan intervals from 5 to 60 seconds (in 5-second increments)
  - `BackgroundScanInterval`: Configure background scan intervals (15s, 30s, 60s, 90s, or 120s)
  - Default: 15 seconds for foreground, 30 seconds for background
  
- **Configurable Retry Queue**: New `MaxQueuedPayloads` enum to control retry queue size
  - `.small` (50 failed batches)
  - `.medium` (100 failed batches) - default
  - `.large` (200 failed batches)
  - `.xlarge` (500 failed batches)
  - Replaces fixed limit with configurable options
  - Each batch can contain multiple beacons from a single sync

### Changed

- **Configuration API**: `configure()` method now accepts enum parameters instead of `Duration`
  - `foregroundScanInterval: ForegroundScanInterval = ForegroundScanInterval.seconds15`
  - `backgroundScanInterval: BackgroundScanInterval = BackgroundScanInterval.seconds30`
  - `maxQueuedPayloads: MaxQueuedPayloads = MaxQueuedPayloads.medium`
  - Old `syncInterval` parameter removed in favor of separate foreground/background intervals

- **Dynamic Interval Switching**: SDK now automatically switches between foreground and background intervals based on app state (iOS only for now)

- **Improved Resilience**: Increased default retry queue from fixed size to 100 failed batches

- **Native SDKs**: Updated to version 2.1.0
  - iOS: `BearoundSDK ~> 2.1.0`
  - Android: `com.github.Bearound:bearound-android-sdk:v2.1.0`

### Migration

**Before (v2.0.1):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'your-business-token-here',
  syncInterval: const Duration(seconds: 30),
);
```

**After (v2.1.0):**
```dart
// Using defaults (recommended)
await BearoundFlutterSdk.configure(
  businessToken: 'your-business-token-here',
);

// Custom configuration
await BearoundFlutterSdk.configure(
  businessToken: 'your-business-token-here',
  foregroundScanInterval: ForegroundScanInterval.seconds30,
  backgroundScanInterval: BackgroundScanInterval.seconds90,
  maxQueuedPayloads: MaxQueuedPayloads.large,
);
```

### Platform Support

- ✅ **iOS**: Fully supports all new features with native SDK 2.1.0
- ✅ **Android**: Fully supports all new features with native SDK 2.1.0

### Technical Details

- Scan duration formula unchanged: `scanDuration = max(5, min(syncInterval / 3, 10))`
- Backoff retry logic unchanged: exponential backoff with max 60s delay
- All existing scanning and sync behaviors preserved
- Type-safe enum-based configuration for better developer experience

---

## [2.0.1] - 2026-01-07

### ⚠️ Breaking Changes

**Authentication Update**: SDK now requires business token instead of appId for authentication.

### Changed

- **API**: `configure()` now requires `businessToken` parameter (replaces `appId`)
- **Auto-detection**: `appId` automatically extracted from package/bundle identifier
- **Authorization**: Business token sent in `Authorization` header for all API requests
- **Native SDKs**: Updated to version 2.0.1
  - Android: `com.github.Bearound:bearound-android-sdk:v2.0.1`
  - iOS: `BearoundSDK ~> 2.0.1`

### Migration

**Before (v2.0.0):**
```dart
await BearoundFlutterSdk.configure(
  appId: 'com.example.app',
  syncInterval: const Duration(seconds: 30),
);
```

**After (v2.0.1):**
```dart
await BearoundFlutterSdk.configure(
  businessToken: 'your-business-token-here',
  syncInterval: const Duration(seconds: 30),
);
// Note: appId is now automatically extracted from package/bundle identifier
```

---

## [2.0.0] - 2026-01-15

### Added
- New Flutter API aligned to the native SDK 2.0.0 (`configure`, `startScanning`, `stopScanning`).
- Streamed updates for beacons, sync status, scanning state, and errors.
- New beacon/metadata models matching native SDK fields.
- User properties support (`setUserProperties`, `clearUserProperties`).

### Changed
- Updated Android native dependency to `com.github.Bearound:bearound-android-sdk:2.0.0`.
- Updated iOS native dependency to `BearoundSDK ~> 2.0.0`.
- Android minimum SDK is now 23; iOS minimum is 13.0.
- Plugin channel payloads updated to match v2 delegate events.

### Removed
- Legacy 1.x API surface (client token initialization, backup size, legacy sync success/error events, region events).

## [1.3.1] - 2025-12-22

### Added
- **Configurable Scan Interval**: Set beacon scan frequency from 5 to 60 seconds via `setSyncInterval()`
  - Balance between battery consumption and detection speed
  - Available intervals: TIME_5, TIME_10, TIME_15, TIME_20 (default), TIME_25, TIME_30, TIME_35, TIME_40, TIME_45, TIME_50, TIME_55, TIME_60
- **Configurable Backup Size**: Set failed beacon backup list size from 5 to 50 beacons via `setBackupSize()`
  - Control how many failed beacon detections are stored for retry
  - Available sizes: SIZE_5 through SIZE_50, default SIZE_40
- **Configuration Methods**: Added `getSyncInterval()` and `getBackupSize()` to retrieve current settings
- **Settings UI**: Added comprehensive settings screen in example app with gear icon in app bar
  - Visual configuration of scan intervals and backup sizes
  - Usage recommendations for different scenarios (real-time tracking, battery optimization, offline-first)
  - Real-time feedback and configuration updates
- **Configuration Enums**: New `SyncInterval` and `BackupSize` enums for type-safe configuration
- **Smart Beacon Filtering**: Automatically filters invalid beacons (RSSI = 0) to improve data quality
- **Improved iOS Integration**: Updated to use singleton pattern with `Bearound.configure()` method

### Changed
- **Updated iOS BearoundSDK dependency to version 1.3.1** with:
  - 🎨 Modular Architecture: Complete project reorganization for better maintainability
  - 📊 Enhanced Telemetry: Comprehensive device information collection
  - 🔋 Battery Optimized: Smart location accuracy settings
  - ✅ RSSI Validation: Improved beacon filtering (-120 to -1 dBm)
  - 🧪 Full Test Coverage: Comprehensive unit test suite
- **Updated Android BearoundSDK dependency to version 1.3.1** with:
  - 🔍 Smart Beacon Filtering: Automatically filters invalid beacons (RSSI = 0)
  - ⚙️ Configurable Scan Intervals: Customizable beacon scan frequency
  - 📦 Configurable Backup List Size: Control failed beacon storage
  - 🎉 Enhanced Event Listener System: BeaconListener, SyncListener, RegionListener
- **iOS SDK Initialization**: Changed from `Bearound(clientToken:isDebugEnable:)` to `Bearound.configure(clientToken:isDebugEnable:)` (singleton pattern)
- **iOS Plugin Architecture**: Implemented Task-based async initialization for reliable permission handling
- Enhanced example app with interactive configuration UI featuring:
  - Current settings display with visual indicators
  - Quick selection chips for all interval and backup size options
  - Usage recommendations for different scenarios
  - Real-time configuration updates

### Performance Improvements
- **iOS**: Async/await pattern ensures proper initialization sequence and reliable beacon detection
- **Memory Management**: Removed all debug print statements from iOS plugin to reduce overhead
- **Event Handling**: Optimized listener callbacks to dispatch events efficiently on main thread

### Technical Details
- **iOS**: 
  - Supports sync intervals from 5-60 seconds and backup sizes from 5-50 beacons
  - Both configurable at runtime (can be changed dynamically)
  - Configuration persisted across app restarts
  - SDK now uses singleton pattern for better lifecycle management
- **Android**: 
  - Supports sync intervals from 5-60 seconds and backup sizes from 5-50 beacons
  - Sync interval can be changed dynamically at runtime
  - Backup size must be set before `initialize()` on Android
  - Configuration persisted across app restarts

### Configuration Recommendations
| Scenario | Sync Interval | Backup Size | Reason |
|----------|---------------|-------------|---------|
| Real-time tracking | TIME_5 - TIME_10 | SIZE_15 - SIZE_20 | Immediate updates, lower backup needed |
| Standard monitoring | TIME_20 - TIME_30 (⭐ default) | SIZE_30 - SIZE_40 | Balanced performance and battery |
| Battery-optimized | TIME_40 - TIME_60 | SIZE_40 - SIZE_50 | Longer intervals, larger backup for reliability |
| Offline-first apps | TIME_30 - TIME_60 | SIZE_50 | Handle poor network conditions |

### API Changes
- Added `BearoundFlutterSdk.setSyncInterval(SyncInterval)` - Configure scan frequency
- Added `BearoundFlutterSdk.setBackupSize(BackupSize)` - Configure backup list size
- Added `BearoundFlutterSdk.getSyncInterval()` - Get current sync interval
- Added `BearoundFlutterSdk.getBackupSize()` - Get current backup size

### Fixed
- **Critical iOS Initialization Bug**: Fixed beacon detection issue where `startServices()` was called before permissions were granted
  - SDK now properly waits for `requestPermissions()` to complete using async/await pattern
  - Matches the working pattern from native iOS SDK example
  - Ensures CoreLocation and CoreBluetooth are properly authorized before starting services
  - Resolves issue where beacons were not being detected on iOS despite successful initialization
- **iOS Event Listeners**: Improved listener registration to ensure events are properly captured from native SDK

### Breaking Changes
- None - This release is backward compatible with 1.2.x versions

## [1.2.0] - 2025-12-08

### Changed
- Updated iOS BearoundSDK dependency to version 1.2.0
- Updated Android BearoundSDK dependency to version 1.2.0

## [1.0.0] - TBD

### Added
- Initial release of Bearound Flutter SDK
- Beacon scanning functionality for Android and iOS
- Permission management for location and Bluetooth
- Comprehensive unit test suite
- CI/CD pipeline with GitHub Actions
- Automatic release workflow

### Features
- **BearoundFlutterSdk**: Main facade for SDK operations
- **BeaconScanner**: Core beacon scanning functionality
- **PermissionService**: Cross-platform permission handling
- **Beacon Model**: Data model for beacon information
- **Method Channel**: Native platform communication

### Documentation
- API documentation with dart doc
- Usage examples
- Setup instructions

### Testing
- Unit tests with 25 test cases
- CI pipeline validation
- Code coverage reporting

## [1.0.1] - 2024-09-11

### Added
- Comprehensive pre-commit hooks configuration
- Automated code quality enforcement (format, analyze, test)
- Security checks with detect-secrets
- Conventional commit message validation
- Setup script for easy pre-commit installation

### Changed  
- Updated Flutter version to 3.35.2 in CI/CD pipelines
- Enhanced documentation with pre-commit hooks guide
- Improved developer workflow with quality automation

### Fixed
- Removed references to unimplemented stream functionality from README
- Corrected API documentation to match actual implementation

## [1.0.3] - 2025-09-17

### Changed
- Migrated iOS dependency from xcframework to official CocoaPods repository
- Updated BeAround dependency to use official CocoaPods spec
- Migrated Android dependency from local .aar files to official JitPack Maven repository
- Updated Android SDK dependency to use `com.github.Bearound:bearound-android-sdk:v1.0.3`
- Improved iOS and Android integration with standardized dependency management

### Fixed
- Resolved iOS build issues related to framework distribution
- Resolved Android build issues related to local .aar dependencies
- Enhanced compatibility with standard CocoaPods and Maven workflows

## [1.1.0] - 2025-10-24

### Added
- **Event Listeners System**: Comprehensive event listener architecture aligned with native iOS and Android SDKs
  - `BeaconListener` - Real-time beacon detection callbacks with event types (enter/exit/failed)
  - `SyncListener` - API synchronization status monitoring (success/error events)
  - `RegionListener` - Beacon region entry/exit notifications
- **EventChannel Streams**: Three dedicated EventChannels for real-time event streaming
  - `beaconsStream` - Stream of detected beacons with event types
  - `syncStream` - Stream of API sync success/error events
  - `regionStream` - Stream of region enter/exit events
- **Enhanced Beacon Model**: Added `lastSeen` field (timestamp in milliseconds)
- **Detailed Debug Logging**: Added comprehensive logging in Android plugin for easier troubleshooting
- **Redesigned Example App**: New tabbed interface with three sections:
  - Beacons tab: Real-time beacon list with region status
  - Sync tab: API synchronization status display
  - Logs tab: Console with timestamped event logs (max 50 entries)

### Changed
- **Region Events Structure**: `BeaconRegionEnterEvent` and `BeaconRegionExitEvent` now use `regionName` instead of beacon list
- **Sync Events Enhancement**:
  - `SyncSuccessEvent` now includes `message` field with server response
  - `SyncErrorEvent` now includes optional `errorCode` field
- **Android Permission Handling**: More flexible permission logic - requires location OR bluetooth (not both)
- **Android SDK Manifest**: Declared all required permissions in SDK manifest for proper merge
- **iOS Beacon Parsing**: Implemented Mirror-based reflection to safely access internal Beacon properties
- **Type Casting**: Improved type safety with explicit `Map<String, dynamic>.from()` conversions

### Fixed
- **iOS UUID Conversion**: Fixed UUID type casting by converting `Foundation.UUID` to `String` using `.uuidString`
- **iOS Distance Conversion**: Fixed `Optional<Float>` to `Double` conversion for `distanceMeters`
- **iOS Major/Minor Types**: Handle both `String` and `Int` types from native SDK
- **Android Bluetooth Permissions**: Added missing `BLUETOOTH` and `BLUETOOTH_ADMIN` permissions to SDK manifest
- **Android Beacon Scanning**: Removed `neverForLocation` flag that was blocking beacon detection
- **Android Permission Inspector Errors**: Resolved all permission-related warnings in beacon scanning
- **Type Cast Errors**: Fixed `Map<Object?, Object?>` to `Map<String, dynamic>` casting issues in event streams

### Infrastructure
- **Git Cleanup**: Removed `.idea/` directories from repository and added to `.gitignore`
- **Android Gitignore**: Updated to ignore entire `.idea/` directory instead of individual files
- **Root Gitignore**: Added comprehensive IDE exclusions (IntelliJ IDEA, VSCode)

### Documentation
- **API Documentation**: Added comprehensive documentation for all new stream getters
- **Usage Examples**: Included examples for all three listener types in code comments
- **BeaconData Model**: Documented all fields including new `lastSeen` timestamp

## [1.1.1] - 2025-11-24

### Fixed
- **State Synchronization Bug**: Fixed critical issue where app state became desynchronized with native SDK after closing and reopening the app
  - Android plugin now checks `BeAround.isInitialized()` before re-initializing, preventing initialization errors
  - When SDK is already initialized, plugin reuses existing instance and re-registers listeners
  - Added `isInitialized()` method to query SDK state from Flutter
  - Example app now implements `WidgetsBindingObserver` to sync UI state when app resumes
  - Background notification now stays consistent with UI state
- **Native Listeners Reconnection**: Fixed issue where beacon events stopped being received after reopening the app
  - Native listeners are now properly re-registered when app detects SDK running in background
  - `_syncStateWithNative()` calls `startScan()` again to restore native event flow
  - Both Flutter streams and native listeners are reconnected seamlessly

### Added
- **State Query Method**: New `BearoundFlutterSdk.isInitialized()` method to check if SDK is currently running
  - Useful for restoring correct UI state when app is reopened
  - Example usage in app lifecycle management
- **Lifecycle Management**: Example app demonstrates proper state synchronization using `WidgetsBindingObserver`

### Changed
- **Android Initialization Logic**: `initialize` method now handles already-initialized state gracefully
  - Logs warning when reusing existing instance
  - Re-registers event listeners to ensure Flutter receives events
  - No error thrown on re-initialization attempts

## [1.1.2] - 2025-11-26

### Changed
- **iOS Native SDK Update**: Updated BearoundSDK iOS dependency from 1.1.0 to 1.1.1
- **iOS Permission Handling**: Added automatic `requestPermissions()` call during SDK initialization
  - Permissions are now requested automatically when initializing the SDK on iOS
  - Improves user experience by ensuring proper permissions setup

### Infrastructure
- Updated Flutter SDK version to 1.1.2
- Updated podspec version to align with SDK versioning

## [Unreleased]

### Planned
- Advanced beacon filtering options
- Enhanced background scanning capabilities
- Performance optimizations
- Battery optimization strategies
