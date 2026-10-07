import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../auth/token_store.dart';
import '../models/app_models.dart';
import '../network/network_status.dart';

class ApiException implements Exception {
  const ApiException(this.message,
      {this.statusCode, this.isConnectionError = false});

  final String message;
  final int? statusCode;
  final bool isConnectionError;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStore tokenStore,
    Dio? dio,
    void Function()? onSessionExpired,
  })  : _tokenStore = tokenStore,
        _onSessionExpired = onSessionExpired,
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
              try {
                if (_skipAuthentication(options)) {
                  options.headers.remove('Authorization');
                } else {
                  final access = await _tokenStore.readAccessToken();
                  if (access != null && access.isNotEmpty) {
                    options.headers['Authorization'] = 'Bearer $access';
                  } else {
                    options.headers.remove('Authorization');
                  }
                }
                handler.next(options);
              } catch (error) {
                handler.reject(
                  DioException(requestOptions: options, error: error),
                );
              }
            },
            onError: (error, handler) async {
              if (_isConnectionError(error)) {
                NetworkStatus.instance.markOffline();
              }
              if (error.response?.statusCode == 401 &&
                  !_skipAuthentication(error.requestOptions)) {
                try {
                  if (error.requestOptions.extra['retried'] == true) {
                    await _expireSession();
                  } else {
                    final currentAccess = await _tokenStore.readAccessToken();
                    final alreadyRefreshed = currentAccess != null &&
                        currentAccess.isNotEmpty &&
                        error.requestOptions.headers['Authorization'] !=
                            'Bearer $currentAccess';
                    if (alreadyRefreshed || await _refreshToken()) {
                      final data = error.requestOptions.data;
                      final retryOptions = error.requestOptions.copyWith(
                        data: data is FormData ? data.clone() : data,
                        extra: {...error.requestOptions.extra, 'retried': true},
                      );
                      final response =
                          await this.dio.fetch<dynamic>(retryOptions);
                      return handler.resolve(response);
                    }
                  }
                } on DioException catch (retryError) {
                  return handler.reject(retryError);
                } catch (retryError) {
                  return handler.reject(DioException(
                    requestOptions: error.requestOptions,
                    error: retryError,
                  ));
                }
              }
              handler.next(error);
            },
          ),
        );
  }

  final TokenStore _tokenStore;
  final void Function()? _onSessionExpired;
  Future<bool>? _refreshInFlight;
  final Dio dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    return _guard(() async {
      try {
        return await dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (!_isConnectionError(error)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 450));
        return dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
        );
      }
    });
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

  Future<Response<dynamic>> uploadBytes(
    String path, {
    required String fieldName,
    required String fileName,
    required List<int> bytes,
  }) async {
    final form = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(bytes, filename: fileName),
    });
    return _guard(() => dio.post<dynamic>(path, data: form));
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      NetworkStatus.instance.markOnline();
      return response;
    } on DioException catch (error) {
      if (_isConnectionError(error)) {
        NetworkStatus.instance.markOffline();
      }
      final message = _errorMessage(
        error.response?.data,
        fallback: error.message ?? 'Something went wrong.',
      );
      throw ApiException(message,
          statusCode: error.response?.statusCode,
          isConnectionError: _isConnectionError(error));
    }
  }

  Future<bool> _refreshToken() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending;
    final refresh = _performTokenRefresh();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _performTokenRefresh() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _expireSession();
      return false;
    }
    try {
      final response = await dio.post<dynamic>(
        '/api/auth/refresh/',
        data: {'refresh': refresh},
        options: Options(extra: {'skipAuth': true}),
      );
      final data = response.data;
      if (data is! Map<String, dynamic> ||
          data['access']?.toString().isNotEmpty != true) {
        await _expireSession();
        return false;
      }
      await _tokenStore.save(AuthTokens(
        access: data['access'].toString(),
        refresh: data['refresh']?.toString() ?? refresh,
      ));
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await _expireSession();
        return false;
      }
      rethrow;
    } catch (_) {
      return false;
    }
  }

  Future<void> _expireSession() async {
    await _tokenStore.clear();
    _onSessionExpired?.call();
  }
}

bool _skipAuthentication(RequestOptions options) {
  return options.extra['skipAuth'] == true ||
      const {
        '/api/auth/login/',
        '/api/auth/register/',
        '/api/auth/refresh/',
      }.contains(Uri.parse(options.path).path);
}

bool _isConnectionError(DioException error) {
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout;
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
    return detail.entries.map((entry) {
      final key = entry.key.toString();
      final message = _detailMessage(entry.value);
      if (_isGeneralErrorKey(key)) return message;
      return '${_friendlyFieldName(key)}: $message';
    }).join(' ');
  }
  return detail.toString();
}

bool _isGeneralErrorKey(String key) {
  final normalized = key.toLowerCase();
  return normalized == 'non_field_errors' ||
      normalized == 'detail' ||
      normalized == 'error' ||
      normalized == 'errors';
}

String _friendlyFieldName(String key) {
  const fieldNames = {
    'food_id': 'Food',
    'meal_type': 'Meal type',
    'quantity_value': 'Quantity',
    'quantity_unit': 'Unit',
    'total_grams': 'Serving weight',
    'display_name': 'Display name',
    'height_cm': 'Height',
    'weight_kg': 'Weight',
    'email': 'Email',
    'password': 'Password',
  };
  return fieldNames[key] ??
      key
          .replaceAll('_', ' ')
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
          .join(' ');
}
