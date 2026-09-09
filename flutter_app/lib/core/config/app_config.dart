class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.invalid',
  );

  // API path prefix for deployments behind a subpath.
  // Example: with '/palmread', '/api/auth/me' becomes '/palmread/api/auth/me'.
  static const String apiBasePath = String.fromEnvironment(
    'API_BASE_PATH',
    defaultValue: '/palmread',
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
