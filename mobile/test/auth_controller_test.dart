import 'package:flutter_test/flutter_test.dart';
import 'package:nutrinova_ai/src/core/models/app_models.dart';
import 'package:nutrinova_ai/src/core/repositories/auth_repository.dart';
import 'package:nutrinova_ai/src/features/auth/auth_controller.dart';

class FakeAuthRepository implements AuthRepository {
  UserProfile? user;

  @override
  Future<UserProfile?> currentUser() async => user;

  @override
  Future<UserProfile> login(String email, String password) async {
    user = UserProfile(
      id: '1',
      email: email,
      displayName: 'Tester',
      hasCompletedOnboarding: true,
    );
    return user!;
  }

  @override
  Future<UserProfile> register(
    String email,
    String password,
    String displayName,
  ) async {
    user = UserProfile(
      id: '1',
      email: email,
      displayName: displayName,
    );
    return user!;
  }

  @override
  Future<void> logout() async {
    user = null;
  }

  @override
  Future<UserProfile> updateProfile(Map<String, dynamic> payload) async {
    user = UserProfile(
      id: user?.id ?? '1',
      email: user?.email ?? 'test@example.com',
      displayName: payload['display_name']?.toString() ?? 'Tester',
      hasCompletedOnboarding: true,
    );
    return user!;
  }
}

void main() {
  test('auth controller logs in and logs out', () async {
    final repository = FakeAuthRepository();
    final controller = AuthController(repository);

    await controller.login('test@example.com', 'password');

    expect(controller.state.value?.email, 'test@example.com');
    expect(controller.state.value?.hasCompletedOnboarding, isTrue);

    await controller.logout();

    expect(controller.state.value, isNull);
  });
}
