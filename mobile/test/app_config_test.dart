import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/config/app_config.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android defaults to its emulator host address', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppConfig.fromEnvironment().apiBaseUrl, 'http://10.0.2.2:8000');
    expect(AppConfig.fromEnvironment().mockMode, isFalse);
  });

  test('iOS defaults to the Mac localhost address', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppConfig.fromEnvironment().apiBaseUrl, 'http://localhost:8000');
  });
}
