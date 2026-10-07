import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/auth_repository.dart';
import '../../core/repositories/providers.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  final controller = AuthController(
    ref.watch(authRepositoryProvider),
    onSessionChanged: (userId) {
      ref.read(sessionUserIdProvider.notifier).state = userId;
    },
  );
  ref.listen<int>(sessionExpiryProvider, (_, __) => controller.load());
  return controller..load();
});

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  AuthController(this._repository, {void Function(String?)? onSessionChanged})
      : _onSessionChanged = onSessionChanged,
        super(const AsyncValue.loading());

  final AuthRepository _repository;
  final void Function(String?)? _onSessionChanged;

  void _setSession(AsyncValue<UserProfile?> value) {
    state = value;
    _onSessionChanged?.call(value.valueOrNull?.id);
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    _setSession(await AsyncValue.guard(_repository.currentUser));
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    _setSession(
        await AsyncValue.guard(() => _repository.login(email, password)));
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncValue.loading();
    _setSession(await AsyncValue.guard(
      () => _repository.register(email, password, displayName),
    ));
  }

  Future<void> completeOnboarding(Map<String, dynamic> payload) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) {
      state = const AsyncValue.loading();
      _setSession(
          await AsyncValue.guard(() => _repository.updateProfile(payload)));
      return;
    }
    final updatedUser = await _repository.updateProfile(payload);
    _setSession(AsyncValue.data(updatedUser));
  }

  Future<void> logout() async {
    await _repository.logout();
    _setSession(const AsyncValue.data(null));
  }
}
