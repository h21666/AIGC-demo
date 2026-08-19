# AIGC Studio Demo Script

## One-Minute Positioning

AIGC Studio is an AI image-generation workflow app. It focuses on durable prompts, reliable queued generation, saved image assets, and a safe path from local TFLite planning to cloud generation.

## Demo Flow

1. Explain prompt management.
   - Prompts are reusable.
   - Tags are normalized.
   - Every meaningful save creates a history snapshot.
   - Rollback creates a new version instead of deleting history.

2. Explain task queue.
   - A `GenerationTask` is a batch.
   - A `GenerationJob` is one image inside the batch.
   - Jobs survive restart.
   - Pause, resume, cancel, retry, and partial failure rules are fixed.

3. Explain cloud generation.
   - SiliconFlow requests go through a client boundary.
   - API key storage is behind a secure-storage interface.
   - 401, 429, timeout, no-network, and server failures are classified.
   - Generated image URLs are downloaded immediately.

4. Explain asset library.
   - Generated images are stored as `GeneratedAsset`.
   - Metadata, prompt snapshot, thumbnail, export state, and source job are recorded.
   - Previews use thumbnails to protect memory.

5. Explain local TFLite planning.
   - Device capability is checked first.
   - Local inference runs behind an isolate-backed boundary.
   - If local execution is unsuitable, the workflow falls back to cloud.

6. Explain settings and logs.
   - API key operations are centralized.
   - Logs are structured and exportable.
   - Cache cleanup has a repository boundary.

## Honest Demo Note

The current build prioritizes product architecture, persistence, state machines, and tests. Full production UI, real platform secure storage, Android gallery export, and real TFLite model performance validation are release-follow-up items.
