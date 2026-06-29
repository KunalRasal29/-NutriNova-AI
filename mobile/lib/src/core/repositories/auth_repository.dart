import '../api/api_client.dart';
import '../auth/token_store.dart';
import '../models/app_models.dart';

abstract class AuthRepository {
  Future<UserProfile?> currentUser();
  Future<UserProfile> login(String email, String password);
  Future<UserProfile> register(
      String email, String password, String displayName);
  Future<void> logout();
  Future<UserProfile> updateProfile(Map<String, dynamic> payload);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(
      {required ApiClient apiClient, required TokenStore tokenStore})
      : _apiClient = apiClient,
        _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final TokenStore _tokenStore;

  @override
  Future<UserProfile?> currentUser() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) return null;
    final response = await _apiClient.get('/api/me/');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> login(String email, String password) async {
    final response = await _apiClient.post(
      '/api/auth/login/',
      data: {'email': email, 'password': password},
    );
    await _tokenStore.save(AuthTokens.fromJson(response.data));
    final me = await _apiClient.get('/api/me/');
    return UserProfile.fromJson(me.data as Map<String, dynamic>);
  }

  @override
  Future<UserProfile> register(
    String email,
    String password,
    String displayName,
  ) async {
    final response = await _apiClient.post(
      '/api/auth/register/',
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    await _tokenStore.save(AuthTokens.fromJson(response.data));
    final me = await _apiClient.get('/api/me/');
    return UserProfile.fromJson(me.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null) {
      try {
        await _apiClient.post('/api/auth/logout/', data: {'refresh': refresh});
      } catch (_) {
        // Token clearing is more important than surfacing a stale logout failure.
      }
    }
    await _tokenStore.clear();
  }

  @override
  Future<UserProfile> updateProfile(Map<String, dynamic> payload) async {
    final response = await _apiClient.patch('/api/me/', data: payload);
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}

class MockAuthRepository implements AuthRepository {
  UserProfile? _user;

  @override
  Future<UserProfile?> currentUser() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _user;
  }

  @override
  Future<UserProfile> login(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _user = UserProfile(
      id: 'mock-user',
      email: email,
      displayName: 'Kunal',
      hasCompletedOnboarding: true,
    );
    return _user!;
  }

  @override
  Future<UserProfile> register(
    String email,
    String password,
    String displayName,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _user = UserProfile(
      id: 'mock-user',
      email: email,
      displayName: displayName,
      hasCompletedOnboarding: false,
    );
    return _user!;
  }

  @override
  Future<void> logout() async {
    _user = null;
  }

  @override
  Future<UserProfile> updateProfile(Map<String, dynamic> payload) async {
    _user = UserProfile(
      id: _user?.id ?? 'mock-user',
      email: _user?.email ?? 'demo@nutrinova.ai',
      displayName:
          payload['display_name']?.toString() ?? _user?.displayName ?? 'You',
      hasCompletedOnboarding: true,
    );
    return _user!;
  }
}
