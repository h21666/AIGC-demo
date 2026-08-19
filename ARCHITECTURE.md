# AIGC Studio Architecture

## Current Phase

Phase 2 adds the first real data feature: a SQLite-backed prompt module with prompt CRUD, version history, tag storage, rollback, and JSON import/export.

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
        sqlite_prompt_repository.dart
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
- `data`: concrete repository implementations. Phase 2 starts with SQLite prompt persistence.
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

The schema is defined in `lib/src/core/database/app_database_schema.dart` and opened through `lib/src/core/database/app_database.dart`.

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

Runtime initialization for the prompt module is implemented in Phase 2 and can be extended for later modules.
