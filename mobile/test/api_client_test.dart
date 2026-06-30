import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/config/app_config.dart';
import 'package:nutrinova_ai/src/core/api/api_client.dart';
import 'package:nutrinova_ai/src/core/auth/token_store.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';

class MemoryTokenStore extends TokenStore {
  AuthTokens? tokens;

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<String?> readAccessToken() async => tokens?.access;

  @override
  Future<String?> readRefreshToken() async => tokens?.refresh;

  @override
  Future<void> save(AuthTokens tokens) async {
    this.tokens = tokens;
  }

  @override
  Future<void> clear() async {
    tokens = null;
  }
}

class MockAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      '{"status":"ok"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{"error":{"status_code":400,"detail":{"food_id":["Choose a food."]}}}',
      400,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('api client sends bearer token and parses mocked response', () async {
    final adapter = MockAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final tokenStore = MemoryTokenStore()
      ..tokens =
          const AuthTokens(access: 'access-token', refresh: 'refresh-token');
    final client = ApiClient(
      config: const AppConfig(apiBaseUrl: 'https://api.test', mockMode: false),
      tokenStore: tokenStore,
      dio: dio,
    );

    final response = await client.get('/api/health/');

    expect(response.data['status'], 'ok');
    expect(
        adapter.lastRequest?.headers['Authorization'], 'Bearer access-token');
  });

  test('api client extracts wrapped backend validation errors', () async {
    final dio = Dio()..httpClientAdapter = ErrorAdapter();
    final client = ApiClient(
      config: const AppConfig(apiBaseUrl: 'https://api.test', mockMode: false),
      tokenStore: MemoryTokenStore(),
      dio: dio,
    );

    await expectLater(
      client.post('/api/meals/manual-add/', data: {'food_id': ''}),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'food_id: Choose a food.',
        ),
      ),
    );
  });
}
