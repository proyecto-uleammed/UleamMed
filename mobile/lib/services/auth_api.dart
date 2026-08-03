import 'dart:convert';

import '../core/http_client.dart';
import '../models/app_role.dart';
import 'local_store.dart';

/// Dominio de autenticacion y sesion: login, registro, recuperacion de
/// contrasena, perfil basico de sesion y logout.
///
/// Unico consumidor de [ApiHttpClient.onSessionExpired]: lo registra en su
/// constructor para que el motor HTTP pueda forzar un logout completo si el
/// refresh token resulta invalido o revocado (401/403 en /auth/refresh).
class AuthApi {
  AuthApi({
    required this._httpClient,
    required this._localStore,
    required this._clearPhotoCache,
  }) {
    _httpClient.onSessionExpired = logout;
  }

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  final Future<void> Function(String userId) _clearPhotoCache;

  Future<AppSession?> restoreSession() async {
    final tokens = await _httpClient.tokenStore.read();
    if (tokens == null) {
      return null;
    }

    _httpClient.setTokensInMemory(tokens);
    try {
      final session = await loadAppSession();
      return _finalizeSession(session);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  Future<AppSession> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _loginUser(email: email, password: password);
    await _httpClient.persistTokens(tokens);
    final session = await loadAppSession();
    return _finalizeSession(session);
  }

  Future<AppSession> register({
    required String email,
    required String password,
    required String fullName,
    AppRole accountType = AppRole.patient,
  }) async {
    if (accountType != AppRole.patient && accountType != AppRole.caregiver) {
      throw const ApiException('Tipo de cuenta no permitido');
    }
    final response = await _httpClient.client.post(
      Uri.parse('${_httpClient.baseUrl}/api/v1/auth/register'),
      headers: ApiHttpClient.jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'account_type': accountType.name,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(
        _httpClient.errorMessageFromResponse(
          response,
          'No se pudo crear la cuenta',
        ),
        response.statusCode,
      );
    }

    await _localStore.clearUserData();
    return login(email: email, password: password);
  }

  Future<AppSession> loadAppSession() async {
    final health = await _httpClient.getJson(
      Uri.parse('${_httpClient.baseUrl}/health'),
    );
    final user = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/users/me'),
      fallback: 'No se pudo cargar el perfil',
    );

    return AppSession(
      apiUrl: _httpClient.baseUrl,
      environment: health['environment']?.toString() ?? 'development',
      user: AppUser.fromJson(user),
    );
  }

  Future<AppSession> updateProfile({required String fullName}) async {
    await _httpClient.patchAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/users/me'),
      body: {'full_name': fullName.trim()},
      fallback: 'No se pudo actualizar el perfil',
    );

    return loadAppSession();
  }

  Future<String> requestPasswordReset({required String email}) async {
    final data = await _httpClient.postPublicJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/auth/forgot-password'),
      body: {'email': email.trim()},
      fallback: 'No se pudo solicitar la recuperacion',
    );
    return data['message']?.toString() ??
        'Si el correo existe, enviaremos instrucciones para restablecer la contrasena.';
  }

  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _httpClient.postPublicJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/auth/reset-password'),
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
      fallback: 'No se pudo restablecer la contrasena',
    );
    return data['message']?.toString() ??
        'Contrasena actualizada correctamente.';
  }

  Future<void> logout() async {
    final activeUserId = await _localStore.readActiveUserId();
    _httpClient.clearTokensInMemory();
    await _httpClient.tokenStore.clear();
    await _localStore.clearUserData();
    await _localStore.clearActiveUserId();
    if (activeUserId != null) {
      await _clearPhotoCache(activeUserId);
    }
  }

  Future<AppSession> _finalizeSession(AppSession session) async {
    final userId = session.user.id.toString();
    final previousUserId = await _localStore.readActiveUserId();
    if (previousUserId != null && previousUserId != userId) {
      _localStore.scopeToUser(previousUserId);
      await _localStore.clearUserData();
    }
    _localStore.scopeToUser(userId);
    await _localStore.saveActiveUserId(userId);

    return session;
  }

  Future<AuthTokens> _loginUser({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.client.post(
      Uri.parse('${_httpClient.baseUrl}/api/v1/auth/login'),
      headers: ApiHttpClient.jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        _httpClient.errorMessageFromResponse(
          response,
          'No se pudo iniciar sesion',
        ),
        response.statusCode,
      );
    }

    return AuthTokens.fromJson(_httpClient.decodeObject(response));
  }
}

class AppSession {
  const AppSession({
    required this.apiUrl,
    required this.environment,
    required this.user,
  });

  final String apiUrl;
  final String environment;
  final AppUser user;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'].toString(),
      fullName: json['full_name']?.toString() ?? 'Usuario',
      isActive: json['is_active'] == true,
      role: AppRole.fromJson(json['role']),
    );
  }

  final int id;
  final String email;
  final String fullName;
  final bool isActive;
  final AppRole role;
}
