# AIGC Studio Deployment Checklist

## Deployment Decision

The current target is an ARM64 Android APK for internal testing. Web remains available for stakeholder preview, and source-code handoff remains available for engineering review.

1. Android APK for internal testing.
2. Web build for quick stakeholder preview.
3. Source-code handoff for engineering review.

The ARM64 Debug APK has been installed and launched successfully on a Xiaomi Android 16 device. This confirms packaging and startup, but does not replace valid-key cloud and gallery-export verification.

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

- Secure API key storage is implemented with `flutter_secure_storage`; a real key must still be checked for persistence after restart.
- Android gallery export is implemented through MediaStore/platform code; successful export still requires a real generated image test.
- Real TFLite inference needs an actual model file and platform performance validation.
- Analyzer and automated test commands have intermittently stalled in the current Windows environment, so the full quality gate must be rerun before release.
- Cloud generation, image persistence, and gallery export cannot be marked passed without a valid SiliconFlow API key.

## Release Output

- GitHub Pages preview URL.
- APK or web artifact.
- Test result summary.
- Known limitations.
- Demo recording.
- Commit hash used for release.
