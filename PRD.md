# AIGC Studio PRD

## Product Goal

AIGC Studio is a Flutter app for managing reusable image generation prompts, running image generation through a reliable task queue, and collecting generated assets in a local material library.

The first implementation phases prioritize data models, core logic, SQLite persistence, and architecture. Complete product pages are deferred until the domain, schema, and state machines are stable.

## Scope By Phase

1. Project skeleton: Flutter project, directory structure, entities, enums, repository interfaces, SQLite schema, and documentation.
2. Prompt module: SQLite initialization, prompt CRUD, prompt versions, tags, history, rollback, JSON import/export, and unit tests.
3. Task queue: generation tasks and jobs, pause/resume/cancel/retry, persistence, and app restart recovery.
4. Cloud generation: Dio client, SiliconFlow API, secure storage, API/network error handling, retry, image download, and task queue integration.
5. Asset library: image metadata, thumbnails, preview, multi-select, album export, permissions, and image memory handling.
6. Local TFLite: model service, interpreter, isolate execution, device capability checks, exception handling, and fallback to cloud.
7. Settings, logs, and tests: API key settings, log viewing/export, cache cleanup, widget tests, integration tests, and exception tests.
8. Final polish: README, architecture refresh, test case refresh, Git feature branches, merge conflict simulation, Android device testing, and demo recording.

## Core Requirements

- Users can create, organize, version, import, and export prompts.
- Users can submit generation work as durable tasks that survive app restarts.
- Users can pause, resume, cancel, and retry generation tasks.
- The system stores generated image files and searchable metadata locally.
- Cloud generation must handle authentication, rate limiting, timeout, and network failures.
- Local TFLite generation is intentionally deferred so it does not block the first five modules.

## Product Decisions

- This version has no account system, project/workspace model, cloud backup, or multi-device sync.
- IDs use UUIDs rather than SQLite auto-increment values.
- Persisted timestamps use UTC.
- `GenerationTask` is the batch concept; no separate `Batch` entity is added.
- Generated image metadata uses `GeneratedAsset` naming.
- Prompt tags are free-form and normalized by trimming, dropping empty tags, and deduplicating within the prompt.
- Prompt versions are automatically created after a valid save transaction when the prompt snapshot changes.
- Rolling back a prompt creates a new version based on the selected historical snapshot.
- Queue concurrency is fixed at 1 for the first version.
- Default retry policy is `maxRetries = 3`, meaning at most 4 total executions per job.
- Running work is recovered as paused after app restart.
- Partial final job failure still completes the task with `failedCount > 0`; only all-final-failed tasks become failed.

## Out Of Scope For Phase 1

- Full prompt management screens.
- SQLite runtime initialization and repository implementations.
- SiliconFlow API calls.
- Image rendering, preview, thumbnail generation, and album export.
- TFLite model execution.
- Complete settings, logs, widget tests, and integration tests.
