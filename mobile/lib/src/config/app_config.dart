import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.mockMode,
  });

  factory AppConfig.fromEnvironment() {
    const configuredUrl = String.fromEnvironment('API_BASE_URL');
    final localUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8000'
        : 'http://localhost:8000';
    return AppConfig(
      apiBaseUrl: configuredUrl.isEmpty ? localUrl : configuredUrl,
      mockMode: bool.fromEnvironment('MOCK_MODE', defaultValue: false),
    );
  }

  final String apiBaseUrl;
  final bool mockMode;
}
