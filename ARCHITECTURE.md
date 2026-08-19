# AIGC Studio Architecture

## Current Phase

Phase 1 defines the project skeleton. It establishes stable names and boundaries before detailed implementation begins.

## Directory Layout

```text
lib/
  main.dart
  src/
    app/
      aigc_studio_app.dart
    core/
      database/
        app_database_schema.dart
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
- `data`: planned for later repository implementations, SQLite access, API clients, secure storage, and file persistence.
- `features`: planned for later UI modules such as prompts, task queue, asset library, settings, and logs.

## Domain Model

- `Prompt`: reusable prompt content plus tags and current version pointer.
- `PromptVersion`: immutable historical prompt snapshot for rollback.
- `GenerationTask`: durable user-level generation request.
- `GenerationJob`: executable unit inside a task.
- `ImageAsset`: generated or imported image metadata.
- `AppSetting`: persisted key-value configuration.
- `AppLogEntry`: structured operational log entry.

## Repository Boundaries

- `PromptRepository`: prompt CRUD, versions, rollback, JSON import/export.
- `GenerationTaskRepository`: task/job persistence plus pause, resume, cancel, and retry commands.
- `AssetRepository`: image asset metadata persistence.
- `SettingsRepository`: application settings and cache cleanup contract.
- `LogRepository`: append, list, export, and clear logs.

## SQLite Schema

The schema is defined in `lib/src/core/database/app_database_schema.dart`.

Version 1 includes:

- `prompts`
- `prompt_versions`
- `prompt_tags`
- `prompt_tag_links`
- `generation_tasks`
- `generation_jobs`
- `image_assets`
- `app_settings`
- `app_logs`

Runtime initialization will be added in Phase 2.
