# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and later TFLite-assisted workflows.

## Current State

- Phase 1: project skeleton and domain boundaries
- Phase 2: SQLite-backed prompt module in progress

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: repository implementations
- `lib/src/app`: app shell

## Next Milestones

- Prompt CRUD, version history, tags, rollback, and JSON import/export
- Generation task queue
- Cloud image generation integration
- Asset library
- Local TFLite support
