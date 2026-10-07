import 'dart:async';
import 'dart:convert';
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

class RoutingAdapter implements HttpClientAdapter {
  RoutingAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Map<String, dynamic> data) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient clientFor(RoutingAdapter adapter, MemoryTokenStore store) =>
    ApiClient(
      config: const AppConfig(apiBaseUrl: 'https://api.test', mockMode: false),
      tokenStore: store,
      dio: Dio()..httpClientAdapter = adapter,
    );

void main() {
  test('temporary read network failure retries without clearing the session',
      () async {
    var calls = 0;
    final adapter = RoutingAdapter((request) async {
      calls++;
      if (calls == 1) {
        throw DioException(
            requestOptions: request, type: DioExceptionType.connectionError);
      }
      return jsonResponse(200, {'status': 'ok'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'access', refresh: 'refresh');
    final response = await clientFor(adapter, store).get('/api/me/');
    expect(response.statusCode, 200);
    expect(calls, 2);
    expect(store.tokens?.refresh, 'refresh');
  });

  test('native uploads have bounded send time and do not replay failed writes',
      () async {
    final client = ApiClient(
      config: const AppConfig(apiBaseUrl: 'https://api.test', mockMode: false),
      tokenStore: MemoryTokenStore(),
    );
    expect(client.dio.options.sendTimeout, const Duration(seconds: 20));
    final adapter = RoutingAdapter((options) async {
      throw DioException(
          requestOptions: options, type: DioExceptionType.sendTimeout);
    });
    client.dio.httpClientAdapter = adapter;
    await expectLater(
      client.uploadBytes('/api/photos/upload/',
          fieldName: 'image', fileName: 'meal.png', bytes: [1, 2, 3]),
      throwsA(isA<ApiException>().having(
          (error) => error.isConnectionError, 'connection error', isTrue)),
    );
    expect(adapter.requests, hasLength(1));
  });

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
          'Food: Choose a food.',
        ),
      ),
    );
  });

  test('expired refresh token fails once and clears the session', () async {
    var refreshCalls = 0;
    final adapter = RoutingAdapter((request) async {
      if (request.path == '/api/auth/refresh/') {
        refreshCalls += 1;
        return jsonResponse(refreshCalls == 1 ? 401 : 500, {
          'detail': 'Token is expired',
        });
      }
      return jsonResponse(401, {'detail': 'Session expired'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'expired');

    await expectLater(
      clientFor(adapter, store).get('/api/me/'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(refreshCalls, 1);
    expect(store.tokens, isNull);
  });

  test(
      'refresh service failure preserves tokens and reports the actual failure',
      () async {
    final adapter = RoutingAdapter((request) async {
      if (request.path == '/api/auth/refresh/') {
        return jsonResponse(503, {'detail': 'Temporarily unavailable'});
      }
      return jsonResponse(401, {'detail': 'Access token expired'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'valid');
    await expectLater(
        clientFor(adapter, store).get('/api/me/'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    expect(store.tokens?.refresh, 'valid');
  });

  test('login ignores saved tokens and does not try to refresh credentials',
      () async {
    final adapter = RoutingAdapter((request) async {
      return jsonResponse(400, {'detail': 'Invalid email or password.'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'old-refresh');

    await expectLater(
      clientFor(adapter, store).post('/api/auth/login/'),
      throwsA(isA<ApiException>()),
    );
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/api/auth/login/');
    expect(
        adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('concurrent expired requests share one token refresh', () async {
    var refreshCalls = 0;
    final adapter = RoutingAdapter((request) async {
      if (request.path == '/api/auth/refresh/') {
        refreshCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return jsonResponse(200, {'access': 'new', 'refresh': 'new-refresh'});
      }
      return request.headers['Authorization'] == 'Bearer new'
          ? jsonResponse(200, {'status': 'ok'})
          : jsonResponse(401, {'detail': 'Access token expired'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'old-refresh');
    final client = clientFor(adapter, store);

    final responses = await Future.wait([
      client.get('/api/me/'),
      client.get('/api/meals/'),
      client.get('/api/habits/today/'),
    ]);

    expect(responses.map((response) => response.statusCode), everyElement(200));
    expect(refreshCalls, 1);
    expect(store.tokens?.refresh, 'new-refresh');
  });

  test('a failed request after refresh returns an error instead of hanging',
      () async {
    final adapter = RoutingAdapter((request) async {
      if (request.path == '/api/auth/refresh/') {
        return jsonResponse(200, {'access': 'new', 'refresh': 'new-refresh'});
      }
      return request.headers['Authorization'] == 'Bearer new'
          ? jsonResponse(403, {'detail': 'Food is no longer available.'})
          : jsonResponse(401, {'detail': 'Access token expired'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'old-refresh');

    await expectLater(
      clientFor(adapter, store)
          .get('/api/foods/private-food/')
          .timeout(const Duration(seconds: 1)),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('photo upload can be replayed after access token refresh', () async {
    final adapter = RoutingAdapter((request) async {
      if (request.path == '/api/auth/refresh/') {
        return jsonResponse(200, {'access': 'new', 'refresh': 'new-refresh'});
      }
      return request.headers['Authorization'] == 'Bearer new'
          ? jsonResponse(201, {'id': 'analysis-1'})
          : jsonResponse(401, {'detail': 'Access token expired'});
    });
    final store = MemoryTokenStore()
      ..tokens = const AuthTokens(access: 'old', refresh: 'old-refresh');

    final response = await clientFor(adapter, store).uploadBytes(
      '/api/photos/analyze-meal/',
      fieldName: 'image',
      fileName: 'meal.jpg',
      bytes: [1, 2, 3],
    ).timeout(const Duration(seconds: 1));

    expect(response.statusCode, 201);
    final uploads = adapter.requests
        .where((request) => request.path == '/api/photos/analyze-meal/')
        .toList();
    expect(uploads, hasLength(2));
    expect(identical(uploads.first.data, uploads.last.data), isFalse);
  });
}
