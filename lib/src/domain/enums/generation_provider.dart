enum GenerationProvider {
  siliconFlow('silicon_flow'),
  localTflite('local_tflite');

  const GenerationProvider(this.storageKey);

  final String storageKey;
}
