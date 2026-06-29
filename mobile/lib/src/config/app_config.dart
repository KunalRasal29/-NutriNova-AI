class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.mockMode,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000',
      ),
      mockMode: bool.fromEnvironment('MOCK_MODE', defaultValue: true),
    );
  }

  final String apiBaseUrl;
  final bool mockMode;
}
