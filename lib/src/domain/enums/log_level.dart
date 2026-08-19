enum LogLevel {
  debug('debug'),
  info('info'),
  warning('warning'),
  error('error');

  const LogLevel(this.storageKey);

  final String storageKey;
}
