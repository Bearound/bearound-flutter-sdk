# Publishing a New Version of bearound_flutter_sdk (pub.dev)

## Prerequisites

- Write access to the [Bearound/bearound-flutter-sdk](https://github.com/Bearound/bearound-flutter-sdk) repository
- pub.dev publisher credentials stored in GitHub Secrets as `PUB_CREDENTIALS`
- The native SDKs **already published** at the version this release pins (see step 1)

---

## 1. Verify the native SDK dependencies are published

This package is a thin bridge over the native SDKs. Releasing it before the
native versions it pins are live will break the example-app build jobs (and any
consumer install). Confirm both are available **first**:

| Native SDK | Registry | Pinned in |
|------------|----------|-----------|
| Android (`bearound-android-sdk`) | [JitPack](https://jitpack.io/#Bearound/bearound-android-sdk) | `android/build.gradle` → `api 'com.github.Bearound:bearound-android-sdk:X.Y.Z'` |
| iOS (`BearoundSDK`) | [CocoaPods](https://cocoapods.org/pods/BearoundSDK) | `ios/bearound_flutter_sdk.podspec` → `s.dependency 'BearoundSDK', 'X.Y.Z'` |

```bash
# Android — verify on JitPack (use the tag WITHOUT the "v" prefix)
curl -s https://jitpack.io/api/builds/com.github.Bearound/bearound-android-sdk/X.Y.Z

# iOS — verify on CocoaPods
curl -s https://trunk.cocoapods.org/api/v1/pods/BearoundSDK | python3 -m json.tool
```

Both native dep pins **must point to a published native version**. If you are
bumping the native SDK too, update those two literals in this same release.

---

## 2. Bump the version

The version lives in **one place**: `pubspec.yaml`.

```yaml
version: X.Y.Z
```

From this single source it flows automatically to:

- the package version published to pub.dev
- the iOS pod version — `ios/bearound_flutter_sdk.podspec` reads `s.version`
  from `pubspec.yaml` at build time:

  ```ruby
  pubspec = YAML.load_file(File.join(__dir__, '..', 'pubspec.yaml'))
  s.version = pubspec['version'].to_s
  ```

> **Never edit a version literal in the podspec.** There isn't one — it is
> derived from `pubspec.yaml`. The release workflow fails if the git tag does
> not match `pubspec.yaml`.

> **Note:** `technology` is a hardcoded constant (`"flutter"`) passed to the
> native `configure(...)` on both platforms. It is **not** versioned and **not**
> a `configure()` parameter — do not touch it when publishing.

Versioning rules ([SemVer](https://semver.org)):

- **MAJOR** (X.0.0) — breaking changes to the public Dart API
- **MINOR** (0.X.0) — new features, backward compatible
- **PATCH** (0.0.X) — bug fixes and internal improvements

---

## 3. Update CHANGELOG.md

Add a new section at the top of the file (just below the header) using this
format:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- Description of new features

### Changed
- Description of changes

### Fixed
- Description of bug fixes

---
```

> **Mandatory.** `flutter pub publish --dry-run` emits a warning (which fails
> the CI `Dependency & Security Validation` job, exit 65) if the CHANGELOG does
> not mention the current version, and `release.yml` greps for the exact
> `## [X.Y.Z]` heading — the release fails if it is missing.

---

## 4. Pre-flight checks (local)

Run the same checks CI runs, before tagging:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .   # must exit 0
flutter analyze --fatal-infos                        # no infos/warnings/errors
flutter test                                         # all green
flutter pub publish --dry-run                        # 0 warnings
```

> If `dart format` reports changes, run `dart format .` to fix them in place,
> then re-run the check.

---

## 5. Commit and push

```bash
git add pubspec.yaml CHANGELOG.md android/build.gradle ios/bearound_flutter_sdk.podspec
git commit -m "chore: bump to vX.Y.Z, align native SDK dependencies"
git push origin main
```

> Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
> (`chore:`, `feat:`, `fix:`).

---

## 6. Create and push the tag

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

> Pushing the tag (`v*`) automatically triggers the **Release** workflow
> (`.github/workflows/release.yml`), which:
>
> 1. Runs tests + `flutter analyze --fatal-infos`
> 2. Runs `flutter pub publish --dry-run`
> 3. Verifies `pubspec.yaml` version == tag
> 4. Verifies `## [X.Y.Z]` exists in CHANGELOG.md
> 5. Publishes to pub.dev (`PUB_CREDENTIALS`)

---

## 7. Watch the workflow

Follow it at: https://github.com/Bearound/bearound-flutter-sdk/actions

Confirm the version is live at: https://pub.dev/packages/bearound_flutter_sdk

---

## Quick Checklist

```
[ ] Native deps published (JitPack + CocoaPods) at the pinned version
[ ] android/build.gradle + podspec point to a published native version
[ ] pubspec.yaml version bumped
[ ] CHANGELOG.md has a ## [X.Y.Z] section
[ ] dart format / flutter analyze / flutter test / pub publish --dry-run all clean
[ ] Commit and push to main
[ ] Tag created: git tag vX.Y.Z
[ ] Tag pushed: git push origin vX.Y.Z
[ ] Workflow green on GitHub Actions
[ ] Version visible on pub.dev
```

---

## Release order across SDKs

When updating the whole Bearound suite, publish in this order — wrappers last,
once the native registries have the new version:

```
1. bearound-android-sdk      -> push tag (JitPack builds automatically)
2. bearound-ios-sdk          -> push tag (CI runs pod trunk push)
3. bearound-react-native-sdk -> bump deps, tag, CI publishes to npm
4. bearound-flutter-sdk      -> bump deps, tag, CI publishes to pub.dev
```

> Always wait for the native SDKs to be available (JitPack + CocoaPods) before
> publishing this package. The `Build Validation (Android/iOS)` jobs build the
> example app against the pinned native version, so they stay red until the
> native SDK for that version is published.

---

## Common Errors

### `flutter pub publish --dry-run` warns "CHANGELOG.md doesn't mention current version"
Add a `## [X.Y.Z]` entry for the current `pubspec.yaml` version at the top of
`CHANGELOG.md`. The dry-run exits 65 on this warning in CI.

### "pubspec (X.Y.Z) != release (A.B.C)"
The git tag does not match `version:` in `pubspec.yaml`. Fix `pubspec.yaml`,
commit, then delete and recreate the tag:
```bash
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z
# fix pubspec.yaml, commit, push
git tag vX.Y.Z
git push origin vX.Y.Z
```

### Example app build fails: cannot resolve `BearoundSDK X.Y.Z` / `bearound-android-sdk:X.Y.Z`
The pinned native version is not published yet. Wait for JitPack/CocoaPods to
have it, or correct the pin in `android/build.gradle` / the podspec.

### `dart format` fails in CI
Run `dart format .` locally to reformat in place, commit the result, then
re-run `dart format --output=none --set-exit-if-changed .` to confirm it exits 0.
