# AIGC Studio Architecture

## Current Phase

Phase 3 adds the durable generation queue on top of the SQLite-backed prompt module.

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
        sqlite_generation_task_repository.dart
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
- `data`: concrete repository implementations for prompt persistence and generation task queues.
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
