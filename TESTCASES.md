# AIGC Studio Test Cases

## Phase 1 Skeleton

- Flutter project can resolve dependencies.
- Flutter analyzer reports no issues in the skeleton code.
- Widget smoke test renders the placeholder app shell.
- Domain entities can be imported through `lib/src/domain/domain.dart`.
- SQLite schema constants expose database name, version, table statements, and index statements.

## Phase 2 Prompt Module

- Create, read, update, archive, and delete prompts.
- Create prompt versions when prompt content changes.
- List prompt version history in descending order.
- Roll back a prompt to a selected historical version.
- Add, remove, and filter by tags.
- Export prompts, versions, and tags to JSON.
- Import valid JSON without duplicating records.
- Reject malformed JSON and preserve existing data.

## Phase 3 Task Queue

- Create tasks and child jobs with `pending` status.
- Move tasks and jobs through `pending`, `running`, `paused`, `failed`, `completed`, and `cancelled`.
- Pause running work without losing queued jobs.
- Resume paused work from the correct pending job.
- Cancel pending or running work and prevent further execution.
- Retry failed tasks up to the configured retry limit.
- Persist task and job state in SQLite.
- Recover unfinished tasks after app restart.

## Phase 4 Cloud Generation

- Store and retrieve API keys through secure storage.
- Send SiliconFlow generation requests through a Dio client.
- Handle 401, 429, timeout, and no-network errors.
- Retry transient failures according to queue policy.
- Download generated images and persist file metadata.
- Link successful jobs to saved image assets.

## Later Phases

- Asset library thumbnail, preview, multi-select, and export workflows.
- Permission denied and permission recovery paths.
- TFLite device capability checks and fallback to cloud.
- Settings, logs, cache cleanup, widget tests, integration tests, and exception tests.
