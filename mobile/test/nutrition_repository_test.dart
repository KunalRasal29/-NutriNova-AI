import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/config/app_config.dart';
import 'package:nutrinova_ai/src/core/api/api_client.dart';
import 'package:nutrinova_ai/src/core/auth/token_store.dart';
import 'package:nutrinova_ai/src/core/repositories/nutrition_repository.dart';

class FoodApi extends ApiClient {
  FoodApi()
      : super(
          config: const AppConfig(apiBaseUrl: 'http://test', mockMode: false),
          tokenStore: TokenStore(),
        );

  bool favorite = false;
  ApiException? error;
  int searchCalls = 0;
  Map<String, dynamic>? lastQuery;

  Map<String, dynamic> get food => {
        'id': 'egg',
        'name': 'Boiled egg',
        'is_favorite': favorite,
        'nutrition_per_100g': {'calories': 155, 'protein_g': 12.6},
      };

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters, CancelToken? cancelToken}) async {
    lastQuery = queryParameters;
    if (error != null) throw error!;
    Object data;
    if (path.endsWith('/search/')) {
      searchCalls += 1;
      data = {
        'count': 1,
        'results': [food]
      };
    } else if (path.endsWith('/egg/')) {
      data = food;
    } else if (path.contains('/tracking/') || path.contains('/habits/')) {
      data = <String, dynamic>{};
    } else {
      data = [food];
    }
    return Response(requestOptions: RequestOptions(path: path), data: data);
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    favorite = true;
    return Response(requestOptions: RequestOptions(path: path), data: {});
  }

  @override
  Future<Response<dynamic>> delete(String path,
      {Map<String, dynamic>? queryParameters}) async {
    favorite = false;
    return Response(requestOptions: RequestOptions(path: path), data: {});
  }
}

class ConcurrentDashboardApi extends FoodApi {
  final paths = <String>[];
  final allStarted = Completer<void>();
  bool fail = false;

  @override
  Future<Response<dynamic>> get(String path,
      {Map<String, dynamic>? queryParameters, CancelToken? cancelToken}) async {
    paths.add(path);
    if (paths.length == 5) allStarted.complete();
    await allStarted.future;
    if (fail && path == '/api/habits/today/') {
      throw const ApiException('Service temporarily unavailable',
          statusCode: 503);
    }
    return Response(
      requestOptions: RequestOptions(path: path),
      data: path == '/api/meals/' ? [] : {'items': <dynamic>[]},
    );
  }
}

void main() {
  test('dashboard starts its independent requests together', () async {
    final api = ConcurrentDashboardApi();
    final snapshot = await ApiNutritionRepository(api)
        .dashboard()
        .timeout(const Duration(seconds: 1));
    expect(api.paths.length, 5);
    expect(snapshot.meals, isEmpty);
  });

  test('dashboard preserves the API error instead of showing a parallel error',
      () async {
    final api = ConcurrentDashboardApi()..fail = true;
    await expectLater(
        ApiNutritionRepository(api).dashboard(),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
  });

  test('favorite toggles invalidate cached search results both ways', () async {
    final api = FoodApi();
    final repository = ApiNutritionRepository(api);
    expect((await repository.searchFoods('egg')).single.isFavorite, isFalse);
    await repository.searchFoods('egg');
    expect(api.searchCalls, 1);
    await repository.setFoodFavorite(foodId: 'egg', isFavorite: true);
    expect((await repository.searchFoods('egg')).single.isFavorite, isTrue);
    await repository.setFoodFavorite(foodId: 'egg', isFavorite: false);
    expect((await repository.searchFoods('egg')).single.isFavorite, isFalse);
    expect(api.searchCalls, 3);
  });

  test('cached foods do not hide access errors or deleted foods', () async {
    final api = FoodApi();
    final repository = ApiNutritionRepository(api);
    await repository.favoriteFoods();
    await repository.foodDetail('egg');
    api.error = const ApiException('Forbidden', statusCode: 403);
    await expectLater(repository.favoriteFoods(), throwsA(isA<ApiException>()));
    api.error = const ApiException('Not found', statusCode: 404);
    await expectLater(
        repository.foodDetail('egg'), throwsA(isA<ApiException>()));
  });

  test('food cache remains available during a connection failure', () async {
    final api = FoodApi();
    final repository = ApiNutritionRepository(api);
    await repository.favoriteFoods();
    await repository.foodDetail('egg');
    api.error = const ApiException('Offline', isConnectionError: true);
    expect((await repository.favoriteFoods()).single.id, 'egg');
    expect((await repository.foodDetail('egg')).id, 'egg');
  });

  test('daily tracking uses the same local date as phone logging', () async {
    final api = FoodApi();
    await ApiNutritionRepository(api).dailyTracking();
    final now = DateTime.now();
    final expected = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    expect(api.lastQuery, {'date': expected});
    await ApiNutritionRepository(api).todayHabits();
    expect(api.lastQuery, {'date': expected});
  });
}
