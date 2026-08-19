# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and TFLite-assisted cloud fallback workflows.

## Current State

- Phases 1-3: project skeleton, SQLite prompt module, and durable task queue implemented.
- Phase 4: SiliconFlow client, secure API key storage, retry/error handling, download, and queue integration implemented; valid-key end-to-end generation remains unverified.
- Phase 5: asset metadata, thumbnails, preview, multi-select, and Android gallery export implemented; successful real-image export remains unverified.
- Phase 6: local capability checks, isolate execution scaffold, and cloud fallback implemented; a real TFLite image model is not bundled.
- Phase 7: settings, logs, presentation controllers, unit/widget/integration test sources, and manual APK cases implemented.
- Phase 8: ARM64 Debug APK builds, installs, and launches on a Xiaomi Android 16 device; release signing and demo recording remain.

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: SQLite repositories, SiliconFlow client, queue runner, and asset library services
- `lib/src/app`: Flutter pages and presentation controllers

## Quality Gates

- `flutter analyze --no-pub`
- `flutter test -r expanded --no-pub`
- `flutter test integration_test/app_test.dart -d windows -r expanded --no-pub`

The integration smoke test requires a desktop/mobile toolchain. In the current Windows environment, the test file is present but Windows execution requires a usable Visual Studio toolchain.

## Release Documents

- `DEPLOYMENT.md`: deployment and release checklist.
- `DEMO_SCRIPT.md`: demo flow for stakeholder walkthroughs.
- `GIT_WORKFLOW.md`: branch strategy and safe merge-conflict simulation notes.

## Remaining Milestones

- Verify a real SiliconFlow generation, downloaded asset, thumbnail, and Android gallery export with a user-provided API key.
- Integrate a licensed, device-compatible TFLite model and its tokenizer/input-output contract, or ship with the documented cloud fallback limitation.
- Configure production application identity, signing, release APK, and demo recording.
