# Git Workflow

## Phase Commits

- Phase 1: `f308123` project skeleton
- Phase 2: `935cddd` prompt module
- Phase 3: `df9198f` generation task queue
- Workflow alignment: `7fe4814`
- Phase 4: `65d6504` cloud generation core
- Phase 5: `10fb8f9` asset library core
- Phase 6: `4f890b9` local TFLite planning
- Queue/fallback polish: `cb98c66`
- Phase 7: `a9b4191` settings, logs, and test scaffolding

## Recommended Branches Going Forward

- `feature/ui-prompt-management`
- `feature/ui-task-queue`
- `feature/android-platform-adapters`
- `feature/release-android`

## Safe Merge Conflict Simulation

Use a disposable branch and a non-production note file for conflict training.

1. Start from a clean worktree.
2. Create `conflict/base-note`.
3. Add the same line to two temporary branches with different text.
4. Merge one branch into the other.
5. Resolve manually.
6. Delete the temporary branches after the exercise.

Do not simulate conflicts directly on `main`.

## Main Branch Rule

`main` should stay green:

- analyzer passes
- unit tests pass
- documentation matches implemented behavior
