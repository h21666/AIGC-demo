# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and TFLite-assisted cloud fallback workflows.

## Current State

- Phase 1: project skeleton and domain boundaries
- Phase 2: SQLite-backed prompt module
- Phase 3: durable generation task queue
- Phase 4: SiliconFlow cloud generation core integration
- Phase 5: generated asset library core
- Phase 6: local TFLite planning and cloud fallback
- Phase 7: settings, logs, and testing
- Phase 8: release cleanup and deployment preparation

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: SQLite repositories, SiliconFlow client, queue runner, and asset library services
- `lib/src/app`: app shell

## Quality Gates

- `flutter analyze --no-pub`
- `flutter test -r expanded --no-pub`
- `flutter test integration_test/app_test.dart -d windows -r expanded --no-pub`

The integration smoke test requires a desktop/mobile toolchain. In the current Windows environment, the test file is present but Windows execution requires a usable Visual Studio toolchain.

## Release Documents

- `DEPLOYMENT.md`: deployment and release checklist.
- `DEMO_SCRIPT.md`: demo flow for stakeholder walkthroughs.
- `GIT_WORKFLOW.md`: branch strategy and safe merge-conflict simulation notes.

## Next Milestones

- Choose release target: Android APK, internal web build, or source-code handoff.
