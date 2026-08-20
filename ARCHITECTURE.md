# AIGC Studio Architecture

## Current Phase

Phase 6 TFLite runtime integration is implemented. The remaining local-AI dependency is an approved, device-compatible text-to-image model package and its model-specific tokenizer/tensor contract.

## Directory Layout

```text
lib/
  main.dart
  src/
    app/
      aigc_studio_app.dart
      controllers/
      pages/
    core/
      database/
        app_database.dart
        app_database_schema.dart
    data/
      repositories/
        sqlite_generated_asset_repository.dart
        sqlite_generation_task_repository.dart
        sqlite_prompt_repository.dart
      clients/
        silicon_flow_image_client.dart
      services/
        application_settings_service.dart
        asset_library_service.dart
        asset_thumbnail_service.dart
        cloud_generation_queue_runner.dart
        default_local_model_capability_service.dart
        file_album_exporter.dart
        generated_image_downloader.dart
        isolate_local_tflite_interpreter.dart
        local_model_manager.dart
        local_tflite_model_service.dart
        platform_album_exporter.dart
        platform_media_permission_service.dart
        sqlite_log_repository.dart
        sqlite_settings_repository.dart
    domain/
      domain.dart
      entities/
      enums/
      repositories/
```

## Layers

- `app`: Flutter application entry and placeholder shell.
- `app/controllers`: lightweight presentation controllers that coordinate page actions with repositories and services.
- `app/pages`: standalone page widgets for secondary screens such as logs.
- `core`: shared infrastructure contracts and constants, starting with SQLite schema definitions.
- `domain`: pure Dart entities, enums, and repository interfaces. This layer does not depend on Flutter widgets, SQLite packages, HTTP clients, or platform APIs.
- `data`: concrete repository implementations, SiliconFlow HTTP client, generated image downloader, queue runner, and asset library services.
- `features`: planned for later UI modules such as prompts, task queue, asset library, settings, and logs.

## Domain Model

- `Prompt`: reusable prompt content plus tags and current version pointer.
- `PromptVersion`: immutable full prompt snapshot for rollback.
- `GenerationTask`: durable batch generation request with a prompt snapshot.
- `GenerationJob`: executable unit inside a task.
- `GeneratedAsset`: generated or imported image metadata.
- `AppSettings`: persisted key-value configuration.
- `AppLog`: structured operational log entry.

## Repository Boundaries

- `PromptRepository`: prompt CRUD, versions, rollback, JSON import/export.
- `GenerationTaskRepository`: task/job persistence plus pause, resume, cancel, and retry commands.
- `AssetRepository`: generated asset metadata persistence.
- `SettingsRepository`: application settings and cache cleanup contract.
- `LogRepository`: append, list, export, and clear logs.

## SQLite Schema

The schema is defined in `lib/src/core/database/app_database_schema.dart` and opened through `lib/src/core/database/app_database.dart`.

Version 2 includes:

- `prompts`
- `prompt_versions`
- `prompt_tags`
- `prompt_tag_links`
- `generation_tasks`
- `generation_jobs`
- `generated_assets`
- `app_settings`
- `app_logs`

Runtime initialization, prompt persistence, and generation task persistence are implemented.

## Queue Decisions

- First release queue concurrency is fixed at 1.
- App restart recovery changes running tasks and jobs to paused.
- Pause does not cancel a running cloud request; it prevents later jobs from starting.
- Cancel preserves failed jobs and generated assets, marks unfinished work as cancelled, and hides the cancelled task from the task queue page. The persisted task record remains available for referential integrity and diagnostics.
- Partial final failure is completed with a non-zero failed count. A task is failed only when every job finally fails, or when a task-level fatal error prevents startup.

## Cloud Generation

- SiliconFlow image requests use `POST /v1/images/generations`.
- The client sends `Authorization: Bearer <apiKey>`.
- Generated image URLs are downloaded immediately and stored as `GeneratedAsset` records.
- Error classification distinguishes authentication, rate limit, timeout, no-network, invalid request, server, and unknown failures.
- Automatic retry is limited to retryable failures and respects each job's `maxAttempts`.
- API keys are accessed through the `SecureApiKeyStore` interface. Runtime builds use `FlutterSecureApiKeyStore`, backed by `flutter_secure_storage` with Android encrypted shared preferences and iOS Keychain options. Tests can still use the in-memory implementation.

## Asset Library

- Generated assets are stored in SQLite with file path, task/job source, prompt snapshot, dimensions, size, MIME type, and export time.
- Asset list previews use thumbnails when available.
- `AssetThumbnailService` creates bounded thumbnails so list screens do not need to decode original images.
- `AssetLibraryService` supports filtered listing, single preview lookup, multi-select export, skipped count, failure count, and per-asset failure messages.
- `MediaPermissionService` and `AlbumExporter` isolate mobile permission/gallery plugins from domain logic.
- Runtime Android builds use `PlatformMediaPermissionService` and `PlatformAlbumExporter` through the `aigc_studio/media` platform channel. Android 10+ exports with MediaStore into `Pictures/AIGC Studio`; Android 9 and below request `WRITE_EXTERNAL_STORAGE`, copy into the public Pictures directory, and trigger media scanning.
- Tests and non-Android development still use `FileAlbumExporter`, which copies files to a local target directory.

## Local TFLite

- `DeviceCapabilityService` inspects the current environment and decides whether local execution is worth attempting.
- `LocalModelManager` streams a user-selected `.tflite` file into private application storage, validates its FlatBuffer identifier, reports file metadata, and removes only app-managed model files.
- `LocalTfliteInterpreter` loads `tflite_flutter` inside an isolate, validates the one-input/one-RGB-output contract, runs inference, and writes a PNG result.
- `LocalTfliteModelService` combines the capability report and interpreter output into a `HybridGenerationPlan`.
- Local success is persisted directly as a `GeneratedAsset` with `source=local`; it does not call SiliconFlow.
- Cloud fallback uses the existing SiliconFlow request shape when the model is missing, incompatible, or inference fails.
- The adapter contract and device setup are documented in `docs/LOCAL_TFLITE.md`; no model weights are bundled in the APK.

## Settings and Logs

- `SqliteSettingsRepository` stores key-value preferences and can clear file-system cache directories.
- `AppSettingsService` wraps secure API key storage together with general app settings and cache cleanup.
- `SqliteLogRepository` stores structured logs, filters them by level and age, exports them as JSON, and clears the log table.
- `PromptController` coordinates prompt CRUD, export/import, version rollback, and task creation from the UI layer.
- `LogController` coordinates log filtering, export, and clearing for the log viewer page.
- `TaskController` coordinates task queue loading, pause/resume/cancel/retry actions, queue execution, and action logging.
- `AssetController` coordinates memory-safe preview loading, selected-asset export, and export result logging.
- `SettingsController` coordinates secure API key operations, system model-file selection/import, cache cleanup, and settings action logging without recording secret values.

## Release Readiness

- Core modules are covered by unit tests.
- The app shell has widget and integration smoke tests.
- Windows integration execution requires Visual Studio tooling.
- ARM64 Debug APK installation and launch have passed on a Xiaomi Android 16 device. Valid-key cloud generation, successful asset persistence, gallery export, and demo recording remain manual release tasks.
