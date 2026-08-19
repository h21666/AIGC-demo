# AIGC Studio Deployment Checklist

## Deployment Decision

Pick one first target before doing release work:

1. Android APK for internal testing.
2. Web build for quick stakeholder preview.
3. Source-code handoff for engineering review.

The current recommendation is Android APK after a real Android device test, because the product is mobile-oriented and depends on local storage, permissions, and future gallery integration.

## Preflight

- Run `flutter analyze --no-pub`.
- Run `flutter test -r expanded --no-pub`.
- Run `flutter doctor -v` on the release machine.
- Confirm Android SDK and Java/Gradle toolchain.
- Confirm whether Windows desktop integration tests need Visual Studio installation.

## Android APK Path

- Set app id, app name, icon, and version.
- Configure release signing outside the repository.
- Run a debug APK first.
- Test on a real Android device:
  - app launch
  - prompt persistence
  - queue pause/resume/cancel/retry
  - cloud error handling
  - generated asset metadata
  - thumbnail creation
  - log export
- Build release APK only after the debug APK passes.

## Web Preview Path

- Build web only as a lightweight preview.
- Treat SQLite/platform storage differences as a known limitation.
- Do not use web preview as the final proof for mobile permissions or local model behavior.

## Release Risks

- Production secure storage still needs the platform plugin implementation.
- Android gallery export needs a platform exporter behind `AlbumExporter`.
- Real TFLite inference needs an actual model file and platform performance validation.
- Integration test execution depends on available platform tooling.

## Release Output

- APK or web artifact.
- Test result summary.
- Known limitations.
- Demo recording.
- Commit hash used for release.
