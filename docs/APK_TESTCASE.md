# AIGC Studio APK Manual Test Case

## Test Target

- APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Platform: Android phone, Android 7.0 / API 24 or above
- CPU architecture: ARM64 / `arm64-v8a`
- Build type: Debug APK

## Test Scope

This test verifies that the current MVP can be installed and that the main user flow is usable on a real Android device:

```text
Open App
  -> create Prompt
  -> create Generation Task
  -> inspect Task Queue
  -> configure API Key
  -> inspect Asset Library
  -> clear cache
```

Cloud image generation requires a valid SiliconFlow API key and network access. If no valid API key is available, the expected result is a readable failure state instead of an app crash.

## Execution Record (2026-08-20)

| Item | Result | Evidence / Limitation |
|---|---|---|
| ARM64 APK installation | Pass | Installed on Xiaomi `2510DRK44C`, Android 16, `arm64-v8a`. |
| Application startup | Pass | `MainActivity` became the foreground activity; dashboard rendered; no fatal startup exception was found. |
| Basic no-key local workflow | Completed | User completed the basic local workflow without a SiliconFlow key. |
| Missing-key generation path | Implemented in installed update | Queued jobs become non-retryable authentication failures and no asset is saved; a valid-key success path remains unavailable. |
| Cancelled task visibility | Implemented in installed update | Cancelled records remain persisted but are hidden from the production task queue; repeat the manual cancel action for final acceptance. |
| Valid-key cloud generation | Blocked | No SiliconFlow API key is available. |
| Real image persistence and gallery export | Blocked | Requires a successful cloud generation result. |
| Real TFLite inference | Not implemented | No compatible model or model input/output contract is available. |

## Pre-conditions

1. Uninstall any older `aigc_studio` build from the phone.
2. Install `AIGC-Studio-arm64-debug.apk`.
3. Allow installing apps from the selected file manager or browser if Android asks.
4. Connect the phone to the internet for cloud generation tests.
5. Prepare a valid SiliconFlow API key for full cloud-generation verification.

## TC-APK-001 App Launch Smoke Test

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Confirm the APK can open and the MVP shell is visible. |
| Steps | 1. Tap the installed AIGC Studio icon. 2. Wait until the home page appears. 3. Check the bottom navigation bar. |
| Expected Result | App opens without crash. Home page shows `创作者工作台`. Bottom tabs show `工作台`, `提示词`, `任务`, `素材`, `设置`. |
| Pass/Fail |  |
| Notes |  |

## TC-APK-002 Prompt Create/Edit/Delete

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify prompt CRUD and basic input validation. |
| Steps | 1. Open `提示词`. 2. Tap `新建`. 3. Enter title `测试提示词`. 4. Enter content `A cyberpunk comic character under neon lights`. 5. Enter tags `漫画, 角色, 夜景`. 6. Save. 7. Tap the prompt and edit the title to `测试提示词 V2`. 8. Save. 9. Delete the prompt only after completing the persistence check below. |
| Expected Result | Prompt can be created and edited. Empty title/content cannot be submitted as a useful prompt. Prompt list refreshes after saving. |
| Pass/Fail |  |
| Notes |  |

## TC-APK-003 Local Persistence After Restart

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify SQLite persistence for prompt data. |
| Steps | 1. Create a prompt using TC-APK-002. 2. Force close the app from Android recent apps. 3. Reopen AIGC Studio. 4. Open `提示词`. |
| Expected Result | The created prompt still exists after app restart. |
| Pass/Fail |  |
| Notes |  |

## TC-APK-004 API Key Configuration

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify the settings entry for SiliconFlow API key. |
| Steps | 1. Open `设置`. 2. Enter a SiliconFlow API key. 3. Tap `保存 API Key`. 4. Check the status icon beside the field. 5. Tap `清除 API Key`. |
| Expected Result | Saving shows a success message. Status icon changes after saving. Clearing removes the key from the field. |
| Pass/Fail |  |
| Notes | Runtime builds store the key through `flutter_secure_storage`; verify persistence after app restart when testing on a real phone. |

## TC-APK-004A Local Model File Selection

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify that a user can configure local inference without entering an Android file path. |
| Steps | 1. Copy a `.tflite` file to the phone. 2. Open `设置`. 3. Tap `选择模型文件`. 4. Select the file in Android's file picker. 5. Review its name, size, file check, and device compatibility result. 6. Restart the app and return to `设置`. 7. Tap `移除模型`. |
| Expected Result | The app copies the model into private storage, displays stable model metadata after restart, and removes the managed copy only after confirmation. An invalid or renamed non-TFLite file shows a readable error and does not replace the previous valid model. |
| Pass/Fail |  |
| Notes | Tensor-contract compatibility is intentionally verified during the first real inference, after the basic file and device checks shown here. |

## TC-APK-005 Create Generation Task

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify prompt-to-task creation and task queue visibility. |
| Steps | 1. Ensure at least one prompt exists. 2. Open `提示词`. 3. Open the prompt menu. 4. Tap `创建生成任务`. 5. Choose `1 张`. 6. Open `任务`. |
| Expected Result | A new task appears in the task queue. It shows task status, progress percentage, success count, failed count, and total job count. |
| Pass/Fail |  |
| Notes | Without a valid API key, pending jobs are marked as non-retryable authentication failures, the task becomes failed, and no asset is saved. |

## TC-APK-006 Task Pause/Resume/Cancel

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify task control buttons do not crash the app and update state. |
| Steps | 1. Create a task with 2 or 4 images. 2. Open `任务`. 3. Tap `暂停` while the task is pending/running. 4. Tap `恢复`. 5. Create another task and tap `取消`. |
| Expected Result | Pause and resume update the task state. After cancellation, the task disappears from the task queue, does not launch new jobs, and any already generated assets remain available. App remains responsive. |
| Pass/Fail |  |
| Notes | Pause does not promise to cancel an already-sent cloud request. |

## TC-APK-007 Cloud Generation With Valid API Key

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify SiliconFlow cloud generation integration on phone. |
| Steps | 1. Open `设置` and save a valid API key. 2. Create a prompt. 3. Create a `1 张` generation task. 4. Keep the app open until task processing finishes. 5. Open `素材`. |
| Expected Result | Task eventually completes or records a readable error. If SiliconFlow returns image URLs successfully, the generated image appears in `素材`. |
| Pass/Fail |  |
| Notes | Requires valid API key, network access, and available SiliconFlow model quota. |

## TC-APK-008 Cloud Error Handling

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify common cloud errors do not crash the app. |
| Steps | 1. Clear the API key. 2. Create a generation task. 3. Observe task behavior. 4. Enter an invalid API key and create another task. 5. Turn off network and create another task. |
| Expected Result | App does not crash. A missing key produces a non-retryable authentication failure and saves no asset. Invalid key and no-network errors produce readable failed states according to retry policy. |
| Pass/Fail |  |
| Notes | Exact message depends on the SiliconFlow/network response. |

## TC-APK-009 Asset Library Preview and Multi-select

| Field | Content |
|---|---|
| Priority | Must-Have |
| Purpose | Verify generated images are visible and selectable. |
| Steps | 1. Complete at least one successful cloud generation. 2. Open `素材`. 3. Tap an asset card. 4. Select multiple assets if available. |
| Expected Result | Asset thumbnails/images are shown. Tapping toggles selected state. Selected assets show checkboxes. |
| Pass/Fail |  |
| Notes | Android runtime export should save selected images into the system gallery under `Pictures/AIGC Studio`. Android 9 and below may request storage permission before export. |

## TC-APK-010 Cache Cleanup

| Field | Content |
|---|---|
| Priority | Should-Have |
| Purpose | Verify cache cleanup action is accessible. |
| Steps | 1. Open `设置`. 2. Tap `清理缓存`. |
| Expected Result | App shows `缓存已清理`. App does not crash. |
| Pass/Fail |  |
| Notes |  |

## TC-APK-011 Log Viewer

| Field | Content |
|---|---|
| Priority | Should-Have |
| Purpose | Verify the log page can open, filter, export, and clear local logs. |
| Steps | 1. Open `设置`. 2. Tap `查看日志`. 3. Switch between log level filters. 4. Tap `导出日志`. 5. Tap `清空日志`. |
| Expected Result | Log page opens normally. Log entries are filterable. Export opens the JSON payload. Clear removes local log entries without crashing. |
| Pass/Fail |  |
| Notes | If the app has not recorded any operational logs yet, the page may initially appear empty. |

## Overall Acceptance Criteria

The APK passes MVP manual testing if:

1. It installs and opens on an ARM64 Android phone.
2. Prompt data can be created and remains after app restart.
3. A generation task can be created from a prompt.
4. Task queue displays status and progress.
5. Missing/invalid API key and network failure do not crash the app.
6. With a valid API key, cloud generation can produce an asset or record a readable failure.
7. Asset library opens without memory-related crash.
8. Log viewer opens and can export/clear local logs.

## Known MVP Limitations

- Real TFLite image generation model is not yet integrated; current local mode is architecture/fallback focused.
- The APK is a Debug build, not a production Release build.
