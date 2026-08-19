enum GenerationJobStatus {
  pending('pending'),
  running('running'),
  paused('paused'),
  failed('failed'),
  completed('completed'),
  cancelled('cancelled');

  const GenerationJobStatus(this.storageKey);

  final String storageKey;
}
