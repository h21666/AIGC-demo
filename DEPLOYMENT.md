# AIGC Studio Deployment Checklist

## Deployment Decision

Pick one first target before doing release work:

1. Android APK for internal testing.
2. Web build for quick stakeholder preview.
3. Source-code handoff for engineering review.

The current recommendation is web preview first, then Android APK. Web is faster to publish for stakeholder review, while Android is the real product target.

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

- Deploy with GitHub Pages from the `main` branch.
- Build with `flutter build web --release --base-href "/AIGC-demo/"`.
- Treat SQLite/platform storage differences as a known limitation.
- Do not use web preview as the final proof for mobile permissions or local model behavior.
- Use the published Pages URL for quick stakeholder review.

## Release Risks

- Production secure storage still needs the platform plugin implementation.
- Android gallery export needs a platform exporter behind `AlbumExporter`.
- Real TFLite inference needs an actual model file and platform performance validation.
- Integration test execution depends on available platform tooling.

## Release Output

- GitHub Pages preview URL.
- APK or web artifact.
- Test result summary.
- Known limitations.
- Demo recording.
- Commit hash used for release.
