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

## [Unreleased]

### Planned
- Real-time beacon event streams
- Advanced beacon filtering options
- Enhanced background scanning capabilities
- Improved error handling and logging
- Performance optimizations
