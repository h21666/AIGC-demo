# Local TFLite Integration

## What is implemented

The app uses the official `tflite_flutter` runtime. Local inference runs inside a Dart isolate and loads the model from the absolute path configured in Settings, validates its tensor contract, executes inference, converts RGB output to PNG, and persists that file as a local `GeneratedAsset`.

The queue calls SiliconFlow only when capability checks fail, the model contract is unsupported, inference throws, or the local output file is missing. A local success does not require an API key.

## Model contract

The adapter supports one numeric input tensor (`float32`, `uint8`, or `int8`) and one RGB output tensor with shape `[1,H,W,3]`, `[H,W,3]`, `[1,3,H,W]`, or `[3,H,W]`. Output values may be `uint8`, `int8`, or normalized `float32` pixels.

This is an explicit runtime adapter contract, not a claim that every TFLite model is text-to-image. A production text-conditioned diffusion model also needs its tokenizer, text encoder, scheduler, UNet, VAE decoder, and model-specific tensor wiring. Those pieces must be supplied as a compatible, licensed model package.

## Device setup

1. Copy the approved `.tflite` model to a readable device location.
2. Open Settings and enter the absolute model path.
3. Create a task and select `本地`.
4. If the model is missing or incompatible, inspect Logs; the task uses cloud fallback when an API key is available.

No model weights or API key are bundled in the APK.
