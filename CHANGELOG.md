# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## [Unreleased]

### Planned
- Advanced beacon filtering options
- Enhanced background scanning capabilities
- Performance optimizations
- Battery optimization strategies
