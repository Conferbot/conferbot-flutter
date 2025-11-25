# Publishing to pub.dev

This guide explains how to publish the Conferbot Flutter SDK to pub.dev (Flutter's package repository).

## Prerequisites

1. **pub.dev Account**: You need a Google account to sign in to pub.dev
2. **Verified Email**: Your pub.dev account email must be verified
3. **Build Passing**: Ensure all tests and analysis pass
4. **Clean Working Directory**: Commit all changes before publishing

## Pre-Publishing Checklist

### 1. Run All Checks

```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Check publish readiness
flutter pub publish --dry-run
```

All commands should pass with **0 errors** and **0 warnings**.

### 2. Update Version

Update the version in `pubspec.yaml` following [Semantic Versioning](https://semver.org/):

- **Patch** (1.0.X): Bug fixes, minor changes
- **Minor** (1.X.0): New features, backward compatible
- **Major** (X.0.0): Breaking changes

Edit `pubspec.yaml`:

```yaml
name: conferbot_flutter
version: 1.0.1  # Update this
```

### 3. Update CHANGELOG

Flutter packages **require** a `CHANGELOG.md` file. Document all changes:

```markdown
# Changelog

## 1.0.1

### Fixed
- Fixed typing indicator animation
- Resolved socket reconnection issue

### Added
- New dark theme
```

### 4. Verify Package Contents

Check which files will be published:

```bash
flutter pub publish --dry-run
```

This shows exactly what will be published based on:
- All files except those in `.gitignore`
- Automatically excludes: `.git/`, `.idea/`, `.vscode/`, `build/`, `.dart_tool/`

**Key Files to Include:**
- `lib/` - All Dart source code
- `README.md` - Package documentation
- `CHANGELOG.md` - Version history (required)
- `pubspec.yaml` - Package metadata
- `LICENSE` - License file (if applicable)

**Files to Exclude** (add to `.gitignore`):
- `example/build/`
- `example/.flutter-plugins`
- `example/.dart_tool/`
- `.vscode/`, `.idea/`
- `*.log`

### 5. Validate pubspec.yaml

Ensure all required fields are present:

```yaml
name: conferbot_flutter
description: Official Flutter SDK for Conferbot - Native mobile chat widget for iOS and Android
version: 1.0.1
homepage: https://docs.conferbot.com/mobile/flutter
repository: https://github.com/conferbot/flutter-sdk
# No license field for proprietary packages

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  socket_io_client: ^2.0.3+1
  http: ^1.1.2
  intl: ^0.18.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

**Required Fields:**
- `name` - Package name (must be lowercase, underscore-separated)
- `description` - 60-180 characters describing the package
- `version` - Semantic version
- `homepage` or `repository` - At least one link

### 6. Score Well on pub.dev

pub.dev assigns scores based on:

1. **Documentation**: Complete README with examples
2. **Example**: Working example in `/example` directory
3. **Analysis**: Zero issues from `flutter analyze`
4. **Platform Support**: Declare supported platforms in pubspec.yaml
5. **Pub Points**: Follow Dart/Flutter conventions

## Publishing

### Step 1: Verify Account

First time publishing from this machine:

```bash
# This will open browser for authentication
flutter pub publish --dry-run
```

Sign in with your Google account.

### Step 2: Dry Run

```bash
# Simulate publish without actually doing it
flutter pub publish --dry-run
```

Review the output carefully:
- Package contents
- Package analysis
- Any warnings or suggestions

### Step 3: Publish

```bash
# Actually publish
flutter pub publish
```

You'll be asked to confirm:
```
Publishing conferbot_flutter 1.0.1 to https://pub.dev:
|-- ...
'-- ...

Do you want to publish conferbot_flutter 1.0.1 (y/N)?
```

Type `y` and press Enter.

### Step 4: Verify Publication

Visit your package page:
```
https://pub.dev/packages/conferbot_flutter
```

Check that:
- Version is updated
- README renders correctly
- Example tab shows your example
- Scores are good (aim for 130/140+ pub points)

### Step 5: Tag Release in Git

```bash
git tag v1.0.1
git push origin main
git push origin --tags
```

## Installation for Users

Once published, users can install via:

```yaml
# pubspec.yaml
dependencies:
  conferbot_flutter: ^1.0.1
```

Or via command line:

```bash
flutter pub add conferbot_flutter
```

The package includes:
- ✅ All Dart source code (`lib/` directory)
- ✅ Documentation comments
- ✅ README and CHANGELOG
- ✅ Example app

## Troubleshooting

### Error: "Package validation failed"

**Solution**: Run `flutter pub publish --dry-run` and fix all issues:

```bash
flutter analyze            # Fix analysis issues
dart format .              # Format code
flutter test              # Fix failing tests
```

### Error: "Version already published"

**Solution**: Increment the version in `pubspec.yaml`:

```yaml
version: 1.0.2  # or 1.1.0 or 2.0.0
```

pub.dev doesn't allow republishing the same version (immutable packages).

### Error: "Package name already taken"

**Solution**: Change the package name in `pubspec.yaml`. Package names must be unique across all of pub.dev.

### Warning: "Missing example"

**Solution**: Include a working example in the `/example` directory:

```
conferbot-flutter/
├── lib/
├── example/
│   ├── lib/
│   │   └── main.dart
│   └── pubspec.yaml
└── pubspec.yaml
```

### Low pub.dev Score

**Solutions**:

1. **Add documentation**:
   - Complete README with usage examples
   - Add doc comments to all public APIs
   - Include example app

2. **Fix analysis issues**:
   ```bash
   flutter analyze --fatal-infos
   ```

3. **Declare platforms**:
   ```yaml
   # pubspec.yaml
   flutter:
     plugin:
       platforms:
         android:
           package: com.conferbot.flutter
         ios:
           pluginClass: ConferBotFlutterPlugin
   ```

4. **Add screenshots** to README:
   ```markdown
   ![Screenshot](https://example.com/screenshot.png)
   ```

## Updating After Publication

### Patch Release (Bug Fixes)

```bash
# 1. Fix the bug
# 2. Update version in pubspec.yaml (1.0.1 -> 1.0.2)
# 3. Update CHANGELOG.md
# 4. Test
flutter test

# 5. Publish
flutter pub publish

# 6. Tag
git tag v1.0.2
git push origin main --tags
```

### Minor Release (New Features)

```bash
# 1. Build new features
# 2. Update docs and examples
# 3. Update version in pubspec.yaml (1.0.2 -> 1.1.0)
# 4. Update CHANGELOG.md
# 5. Test
flutter test

# 6. Publish
flutter pub publish

# 7. Tag
git tag v1.1.0
git push origin main --tags
```

### Major Release (Breaking Changes)

```bash
# 1. Make breaking changes
# 2. Write migration guide in CHANGELOG.md
# 3. Update version in pubspec.yaml (1.1.0 -> 2.0.0)
# 4. Update all documentation
# 5. Test thoroughly
flutter test

# 6. Publish
flutter pub publish

# 7. Tag
git tag v2.0.0
git push origin main --tags
```

## Best Practices

1. **Always test before publishing**:
   ```bash
   cd example && flutter run
   ```

2. **Semantic versioning**: Follow semver strictly
   - Patch: Bug fixes only
   - Minor: New features, backward compatible
   - Major: Breaking changes

3. **CHANGELOG.md**: Document every change
   - Group by Added, Changed, Deprecated, Removed, Fixed, Security

4. **Git tags**: Tag every release
   ```bash
   git tag -a v1.0.1 -m "Release 1.0.1"
   ```

5. **README.md**: Keep comprehensive
   - Installation
   - Quick start
   - Full examples
   - API reference link

6. **Example app**: Always up-to-date
   - Demonstrates all major features
   - Actually runs without errors

7. **Documentation**: Add dartdoc comments
   ```dart
   /// Opens the chat interface.
   ///
   /// Initializes a new session if [chatSessionId] is null.
   /// Returns a [Future] that completes when chat is opened.
   Future<void> openChat() async { ... }
   ```

8. **Version constraints**: Use caret syntax
   ```yaml
   dependencies:
     provider: ^6.1.1  # Allows 6.1.1 to <7.0.0
   ```

## Automated Publishing (CI/CD)

For automated publishing via GitHub Actions:

```yaml
# .github/workflows/publish.yml
name: Publish to pub.dev

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Analyze
        run: flutter analyze

      - name: Publish
        uses: k-paxian/dart-package-publisher@v1.5.1
        with:
          credentialJson: ${{ secrets.PUB_CREDENTIALS }}
          flutter: true
          skipTests: true
```

**Setup**:
1. Run `flutter pub publish --dry-run` locally to generate credentials
2. Credentials are in `~/.pub-cache/credentials.json`
3. Add as GitHub secret: `PUB_CREDENTIALS`

## Retraction (Emergency)

If you need to retract a published version:

```bash
# Mark version as retracted (doesn't delete it)
flutter pub global activate pub_api_client
dart pub global run pub_api_client:main retract conferbot_flutter 1.0.1
```

**Note**: Retraction doesn't delete the package, it just marks it as "do not use". You should publish a new fixed version immediately.

## Quick Reference

```bash
# Full publishing workflow
flutter analyze               # Check code quality
dart format .                 # Format code
flutter test                  # Run tests
flutter pub publish --dry-run # Verify package
# Update version in pubspec.yaml
# Update CHANGELOG.md
flutter pub publish           # Publish to pub.dev
git tag v1.0.1               # Tag release
git push --tags              # Push tags
```

## Resources

- **pub.dev**: https://pub.dev/
- **Publishing guide**: https://dart.dev/tools/pub/publishing
- **Package layout**: https://dart.dev/tools/pub/package-layout
- **Semantic versioning**: https://semver.org/
- **Dart conventions**: https://dart.dev/effective-dart
- **Package scoring**: https://pub.dev/help/scoring
