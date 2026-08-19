# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and later TFLite-assisted workflows.

## Current State

- Phase 1: project skeleton and domain boundaries
- Phase 2: SQLite-backed prompt module
- Phase 3: durable generation task queue
- Phase 4: SiliconFlow cloud generation core integration

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: SQLite repositories, SiliconFlow client, download service, and queue runner
- `lib/src/app`: app shell

## Next Milestones

- Asset library
- Local TFLite support
