# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and later TFLite-assisted workflows.

## Current State

- Phase 1: project skeleton and domain boundaries
- Phase 2: SQLite-backed prompt module
- Phase 3: durable generation task queue
- Phase 4: SiliconFlow cloud generation core integration
- Phase 5: generated asset library core
- Phase 6: local TFLite planning and cloud fallback

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: SQLite repositories, SiliconFlow client, queue runner, and asset library services
- `lib/src/app`: app shell

## Next Milestones

- Settings, logs, and tests
