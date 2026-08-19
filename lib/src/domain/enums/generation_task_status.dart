enum GenerationTaskStatus {
  pending('pending'),
  running('running'),
  paused('paused'),
  failed('failed'),
  completed('completed'),
  cancelled('cancelled');

  const GenerationTaskStatus(this.storageKey);

  final String storageKey;
}
