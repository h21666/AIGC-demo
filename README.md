# AIGC Studio

A Flutter app for prompt management, queued image generation, local asset storage, and later TFLite-assisted workflows.

## Current State

- Phase 1: project skeleton and domain boundaries
- Phase 2: SQLite-backed prompt module
- Phase 3: durable generation task queue

## Project Layout

- `lib/src/domain`: entities, enums, and repository contracts
- `lib/src/core/database`: SQLite schema and runtime database bootstrap
- `lib/src/data`: SQLite repository implementations
- `lib/src/app`: app shell

## Next Milestones

- Cloud image generation integration
- Asset library
- Local TFLite support
