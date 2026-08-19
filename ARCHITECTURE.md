# AIGC Studio Architecture

## Current Phase

Phase 5 adds the generated asset library core: metadata queries, thumbnails, preview data, multi-select export, permission abstraction, and image memory safeguards.

## Directory Layout

```text
lib/
  main.dart
  src/
    app/
      aigc_studio_app.dart
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
        asset_library_service.dart
        asset_thumbnail_service.dart
        cloud_generation_queue_runner.dart
        file_album_exporter.dart
        generated_image_downloader.dart
    domain/
      domain.dart
      entities/
      enums/
      repositories/
```

## Layers

- `app`: Flutter application entry and placeholder shell.
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
- Partial final failure is completed with a non-zero failed count. A task is failed only when every job finally fails, or when a task-level fatal error prevents startup.

## Cloud Generation

- SiliconFlow image requests use `POST /v1/images/generations`.
- The client sends `Authorization: Bearer <apiKey>`.
- Generated image URLs are downloaded immediately and stored as `GeneratedAsset` records.
- Error classification distinguishes authentication, rate limit, timeout, no-network, invalid request, server, and unknown failures.
- Automatic retry is limited to retryable failures and respects each job's `maxAttempts`.
- The first production secure-storage implementation is behind the `SecureApiKeyStore` interface. The current repository includes an in-memory implementation for tests and local core development because `flutter_secure_storage` requires Windows Developer Mode in this environment.

## Asset Library

- Generated assets are stored in SQLite with file path, task/job source, prompt snapshot, dimensions, size, MIME type, and export time.
- Asset list previews use thumbnails when available.
- `AssetThumbnailService` creates bounded thumbnails so list screens do not need to decode original images.
- `AssetLibraryService` supports filtered listing, single preview lookup, multi-select export, skipped count, failure count, and per-asset failure messages.
- `MediaPermissionService` and `AlbumExporter` isolate mobile permission/gallery plugins from domain logic.
- The checked-in exporter copies files to a target directory for tests and desktop development. Android/iOS gallery export can be added behind `AlbumExporter` when plugin symlink support is available.
