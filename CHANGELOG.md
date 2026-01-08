# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
