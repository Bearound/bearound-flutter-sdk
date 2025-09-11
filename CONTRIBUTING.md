# Contributing to Bearound Flutter SDK

We welcome contributions to the Bearound Flutter SDK! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.8.1 or higher
- Dart SDK (included with Flutter)
- Git
- A GitHub account

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/bearound-flutter-sdk.git
   cd bearound-flutter-sdk
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 📋 Development Guidelines

### Code Style

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart)
- Use `dart format .` to format your code
- Run `flutter analyze` to check for issues
- Ensure your code passes all linting rules

### Testing

- Write unit tests for new functionality
- Maintain or improve test coverage
- Run tests locally: `flutter test`
- Add integration tests when appropriate

### Documentation

- Document all public APIs with DartDoc comments
- Update README.md for significant changes
- Update CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/) format
- Include code examples for new features

## 🧪 Testing Your Changes

### Unit Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/path/to/test_file.dart
```

### Code Quality Checks

```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Check for dependency issues
flutter pub deps
```

### Build Verification

```bash
# Test Android build
cd example
flutter build apk --debug

# Test iOS build (macOS only)
flutter build ios --debug --no-codesign
```

## 📝 Submitting Changes

### Pull Request Process

1. **Ensure your changes are tested** with unit tests
2. **Update documentation** as needed
3. **Update CHANGELOG.md** with your changes
4. **Create a pull request** with:
   - Clear title and description
   - Reference to any related issues
   - Screenshots for UI changes
   - List of breaking changes (if any)

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Documentation updated

## Screenshots
(If applicable)

## Breaking Changes
(If any)

## Additional Notes
(Optional)
```

### Commit Guidelines

Use conventional commit messages:

```
type(scope): description

body (optional)

footer (optional)
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test changes
- `chore`: Build/tool changes

**Examples:**
```
feat(scanner): add background scanning support
fix(permissions): handle Android 12+ permissions correctly
docs(readme): update installation instructions
test(beacon): add unit tests for beacon model
```

## 🐛 Reporting Issues

### Bug Reports

When reporting bugs, please include:

1. **Flutter version** (`flutter --version`)
2. **Operating System** and version
3. **Device information** (if relevant)
4. **Steps to reproduce** the bug
5. **Expected behavior**
6. **Actual behavior**
7. **Error messages** or logs
8. **Minimal code example** demonstrating the issue

### Feature Requests

For feature requests, please:

1. **Search existing issues** to avoid duplicates
2. **Describe the feature** and its use case
3. **Explain why** it would be beneficial
4. **Provide examples** of how it would be used
5. **Consider backward compatibility**

## 🏗️ Project Structure

```
bearound_flutter_sdk/
├── lib/
│   ├── src/
│   │   ├── core/           # Core functionality
│   │   └── data/           # Data models
│   ├── bearound_flutter_sdk.dart
│   └── ...
├── test/
│   ├── src/                # Unit tests
│   └── ...
├── example/                # Example app
├── android/                # Android implementation
├── ios/                    # iOS implementation
└── ...
```

## 📚 Resources

- [Flutter Plugin Development](https://docs.flutter.dev/development/packages-and-plugins/developing-packages)
- [Dart Documentation](https://dart.dev/guides)
- [Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Method Channels](https://api.flutter.dev/flutter/services/MethodChannel-class.html)

## 🤝 Code of Conduct

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment include:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team at support@bearound.com.

## 🏆 Recognition

Contributors will be recognized in:

- Release notes for significant contributions
- README.md contributors section
- Special thanks in documentation

## 📞 Getting Help

If you need help contributing:

- 💬 [GitHub Discussions](https://github.com/Bearound/bearound-flutter-sdk/discussions)
- 📧 Email: support@bearound.com
- 🐛 [Issue Tracker](https://github.com/Bearound/bearound-flutter-sdk/issues)

Thank you for contributing to Bearound Flutter SDK! 🎉