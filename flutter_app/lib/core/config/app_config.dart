class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://51.255.201.31:8080',
  );

  static const int pollIntervalSeconds = int.fromEnvironment(
    'POLL_INTERVAL_SECONDS',
    defaultValue: 2,
  );

  static const int uploadTimeoutSeconds = int.fromEnvironment(
    'UPLOAD_TIMEOUT_SECONDS',
    defaultValue: 30,
  );
}
