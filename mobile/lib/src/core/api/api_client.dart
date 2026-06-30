import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../auth/token_store.dart';
import '../models/app_models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    Dio? dio,
  })  : _tokenStore = tokenStore,
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: config.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Accept': 'application/json'},
              ),
            ) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final access = await _tokenStore.readAccessToken();
              if (access != null && access.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $access';
              }
              handler.next(options);
            },
            onError: (error, handler) async {
              if (error.response?.statusCode == 401 &&
                  error.requestOptions.extra['retried'] != true) {
                final refreshed = await _refreshToken();
                if (refreshed) {
                  final retryOptions = error.requestOptions;
                  retryOptions.extra['retried'] = true;
                  final response = await this.dio.fetch<dynamic>(retryOptions);
                  return handler.resolve(response);
                }
              }
              handler.next(error);
            },
          ),
        );
  }

  final TokenStore _tokenStore;
  final Dio dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _guard(
      () => dio.get<dynamic>(path, queryParameters: queryParameters),
    );
  }

  Future<Response<dynamic>> post(String path, {Object? data}) async {
    return _guard(() => dio.post<dynamic>(path, data: data));
  }

  Future<Response<dynamic>> patch(String path, {Object? data}) async {
    return _guard(() => dio.patch<dynamic>(path, data: data));
  }

  Future<Response<dynamic>> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _guard(
      () => dio.delete<dynamic>(path, queryParameters: queryParameters),
    );
  }

  Future<Response<dynamic>> uploadFile(
    String path, {
    required String fieldName,
    required String filePath,
  }) async {
    final form = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
    });
    return _guard(() => dio.post<dynamic>(path, data: form));
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final message = _errorMessage(
        error.response?.data,
        fallback: error.message ?? 'Something went wrong.',
      );
      throw ApiException(message, statusCode: error.response?.statusCode);
    }
  }

  Future<bool> _refreshToken() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await dio.post<dynamic>(
        '/api/auth/refresh/',
        data: {'refresh': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      if (response.data is! Map<String, dynamic>) return false;
      await _tokenStore.save(AuthTokens.fromJson(response.data));
      return true;
    } catch (_) {
      await _tokenStore.clear();
      return false;
    }
  }
}

String _errorMessage(Object? data, {required String fallback}) {
  if (data is Map) {
    final error = data['error'];
    if (error is Map && error['detail'] != null) {
      return _detailMessage(error['detail']);
    }
    if (data['detail'] != null) {
      return _detailMessage(data['detail']);
    }
  }
  return fallback;
}

String _detailMessage(Object? detail) {
  if (detail == null) return 'Something went wrong.';
  if (detail is String) return detail;
  if (detail is List) {
    return detail.map(_detailMessage).join(' ');
  }
  if (detail is Map) {
    return detail.entries
        .map((entry) => '${entry.key}: ${_detailMessage(entry.value)}')
        .join(' ');
  }
  return detail.toString();
}
