# AIGC Studio Test Cases

## Phase 1 Skeleton

- Flutter project can resolve dependencies.
- Flutter analyzer reports no issues in the skeleton code.
- Widget smoke test renders the placeholder app shell.
- Domain entities can be imported through `lib/src/domain/domain.dart`.
- SQLite schema constants expose database name, version, table statements, and index statements.

## Phase 2 Prompt Module

- Create, read, update, archive, and delete prompts.
- Automatically create prompt versions when prompt snapshot content changes.
- Store prompt version snapshots with title, content, and tags.
- List prompt version history in descending order.
- Roll back a prompt by creating a new version from a selected historical version.
- Add, remove, and filter by tags.
- Export prompts, versions, and tags to JSON.
- Import valid JSON without duplicating records.
- Reject ID conflicts instead of silently overwriting local prompts.
- Reject malformed JSON and preserve existing data.

## Phase 3 Task Queue

- Create tasks and child jobs with `pending` status.
- Move tasks and jobs through `pending`, `running`, `paused`, `failed`, `completed`, and `cancelled`.
- Pause running work without losing queued jobs.
- Resume paused work from the correct pending job.
- Cancel pending or running work and prevent further execution.
- Preserve failed jobs when canceling a task.
- Retry failed tasks up to the configured retry limit.
- Persist task and job state in SQLite.
- Recover running tasks and jobs as paused after app restart.
- Keep running jobs running when pause is requested and pause only later pending work.
- Mark partial final failure as completed with a non-zero failed count.
- Mark all-final-failed tasks as failed.
- Calculate progress with processed jobs, not successful jobs only.

## Phase 4 Cloud Generation

- Store and retrieve API keys through the `SecureApiKeyStore` boundary.
- Send SiliconFlow generation requests through a Dio client.
- Handle 401, 429, timeout, and no-network errors.
- Retry transient failures according to queue policy.
- Do not retry authentication failures.
- Download generated images and persist file metadata.
- Link successful jobs to saved generated assets.
- Complete the corresponding generation job after asset persistence.
- Mark failed jobs according to retry exhaustion and error type.

## Later Phases

- Deployment target selection, signing setup, and store/internal distribution.

## Phase 5 Asset Library

- Persist generated image metadata in SQLite.
- List assets by task, date range, and limit.
- Read assets by selected IDs while preserving selection order.
- Generate thumbnails with bounded dimensions.
- Build preview models that prefer thumbnails over original images.
- Export selected assets through the album exporter boundary.
- Mark exported assets with `exportedAt`.
- Deny export cleanly when media permission is not granted.
- Continue batch export when one selected file is missing.
- Report skipped IDs separately from failed file/export operations.

## Phase 6 Local TFLite

- Detect whether local execution is supported on the current device.
- Run local inference through an isolate-backed interpreter.
- Refine the cloud prompt when local inference succeeds.
- Return a cloud fallback plan when the local model is unavailable.
- Return a cloud fallback plan when local inference raises an exception.
- Keep the cloud request payload aligned with the existing SiliconFlow request schema.

## Phase 7 Settings, Logs, and Tests

- Save and clear the API key through the settings service.
- Persist general settings in SQLite.
- Clear cache directories through the settings repository boundary.
- Append, filter, export, and clear structured logs.
- Route prompt, task, asset, settings, and log page operations through presentation controllers.
- Ensure settings logs never contain API key values.
- Record selected, exported, skipped, and failed counts for asset export actions.
- Run a widget smoke test against the app shell.
- Run an integration smoke test against the app entry point.
- Verify cloud and local exception classification paths.

## Phase 8 Final Polish

- README lists current phase status, quality gates, and release documents.
- Architecture document reflects the implemented modules and known environment limits.
- Test case document separates completed phases from deployment follow-up.
- Deployment checklist identifies Android, web, and source-code handoff options.
- Demo script explains the product flow without requiring unfinished full pages.

## Manual APK Testing

- `docs/APK_TESTCASE.md` records the phone-side manual MVP test flow for installing the ARM64 APK, creating prompts, creating tasks, checking task controls, configuring API key behavior, inspecting the asset library, and validating graceful error handling.

## Execution Status (2026-08-20)

- Passed: 15 targeted automated tests covering asset persistence/preview/export, settings/logs, cloud success simulation, authentication errors, timeout retry, missing-key failure, and local fallback planning.
- Passed: ARM64 Debug APK compilation at `build/app/outputs/flutter-apk/app-debug.apk`.
- Passed: ARM64 Debug APK installation on Xiaomi `2510DRK44C`, Android 16, `arm64-v8a`.
- Passed: application launch, foreground activity, rendered creator dashboard, and no fatal startup exception.
- Completed by user: basic no-key local workflow testing.
- Implemented in the current build: missing API key marks queued jobs as authentication failures without retries or saved assets.
- Implemented in the current build: cancelled tasks are hidden from the production queue while persisted records and generated assets remain intact.
- Blocked by missing API key: successful SiliconFlow generation, image download, asset persistence, thumbnail verification, and Android gallery export.
- Not completed: real TFLite model inference, release signing, Release APK, and demo recording.
- Environment limitation: the static analyzer session stalled before returning a final result and is not recorded as passed; the targeted automated suite and APK compilation passed separately.
