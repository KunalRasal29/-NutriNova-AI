import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../api/api_client.dart';
import '../auth/token_store.dart';
import 'auth_repository.dart';
import 'nutrition_repository.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return TokenStore();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    config: ref.watch(appConfigProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.mockMode) return MockAuthRepository();
  return ApiAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.mockMode) return MockNutritionRepository();
  return ApiNutritionRepository(ref.watch(apiClientProvider));
});
