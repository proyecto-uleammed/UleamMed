import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

/// Motor HTTP y de sesion compartido por todos los `*Api` de dominio
/// (`AuthApi`, `SyncApi`, `HealthApi`, `MedicationApi`, `CaregivingApi`).
/// Ningun dominio golpea `http.Client` directamente: todos pasan por aca
/// para resolucion de `baseUrl`, tokens en memoria y refresh con
/// single-flight.
class ApiHttpClient {
  ApiHttpClient({http.Client? client, String? baseUrl, TokenStore? tokenStore})
    : client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl,
      tokenStore = tokenStore ?? SecureTokenStore();

  final http.Client client;
  final String baseUrl;
  final TokenStore tokenStore;

  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshInFlight;

  /// Se invoca cuando el refresh token es invalido/revocado (401/403) y hay
  /// que cerrar la sesion local. `AuthApi` lo registra en su constructor
  /// para ejecutar su `logout()` completo (limpia LocalStore, cache de
  /// fotos, etc.). Si nadie lo registra, se hace un clear minimo de tokens.
  Future<void> Function()? onSessionExpired;

  static const _productionBaseUrl = 'https://d18ajxqltdcc9k.cloudfront.net';

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('ULEAMMED_API_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }
    if (kDebugMode) {
      return _localDevBaseUrl;
    }
    return _productionBaseUrl;
  }

  static String get _localDevBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }

  static const Map<String, String> jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void close() => client.close();

  void setTokensInMemory(AuthTokens tokens) {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
  }

  void clearTokensInMemory() {
    _accessToken = null;
    _refreshToken = null;
    _refreshInFlight = null;
  }

  Future<void> persistTokens(AuthTokens tokens) async {
    setTokensInMemory(tokens);
    await tokenStore.save(tokens);
  }

  Future<String> ensureAccessToken() async {
    if (_accessToken != null) {
      return _accessToken!;
    }

    final tokens = await tokenStore.read();
    if (tokens != null) {
      setTokensInMemory(tokens);
      return tokens.accessToken;
    }

    throw const ApiException('Sesion no iniciada', 401);
  }

  /// Error tras un 401 cuando el refresh no pudo recuperar la sesion.
  ///
  /// Si el refresh ya cerro la sesion (refresh invalido), se reporta 401.
  /// Si el refresh fallo por red/5xx, se conserva la sesion y se reporta
  /// 503 para que la app siga con cache local.
  ApiException sessionRefreshFailure() {
    final sessionStillAlive = _accessToken != null || _refreshToken != null;
    if (sessionStillAlive) {
      return const ApiException(
        'No se pudo renovar la sesion. Intenta de nuevo.',
        503,
      );
    }
    return const ApiException(
      'Sesion expirada, inicia sesion nuevamente',
      401,
    );
  }

  /// Renueva el access token colapsando llamadas concurrentes.
  ///
  /// Varias peticiones en paralelo (por ejemplo `listMedications()` y
  /// `listDoseConfirmations()` en la misma pantalla) pueden recibir 401 a la
  /// vez. Sin este control, cada una dispararia su propio POST /auth/refresh.
  ///
  /// [staleToken] es el access token con el que fallo la peticion. Si para
  /// cuando llegamos aqui el token en memoria ya es otro, significa que otra
  /// peticion renovo con exito y basta con reintentar.
  Future<bool> refreshAccessToken({String? staleToken}) {
    final currentToken = _accessToken;
    if (staleToken != null &&
        currentToken != null &&
        currentToken != staleToken) {
      return Future<bool>.value(true);
    }

    return _refreshInFlight ??= _performTokenRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Ejecuta el refresh real. Solo debe invocarse desde [refreshAccessToken].
  ///
  /// Politica de cierre de sesion: solo se cierra ante 401/403, que
  /// significan refresh token invalido o revocado. Un 5xx, un timeout o la
  /// falta de red NO cierran la sesion: la app queda operando con su cache
  /// local.
  Future<bool> _performTokenRefresh() async {
    var refreshToken = _refreshToken;
    if (refreshToken == null) {
      final stored = await tokenStore.read();
      if (stored == null) {
        return false;
      }
      setTokensInMemory(stored);
      refreshToken = stored.refreshToken;
    }

    final http.Response response;
    try {
      response = await client.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: jsonHeaders,
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on TimeoutException {
      return false;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      if (onSessionExpired != null) {
        await onSessionExpired!();
      } else {
        clearTokensInMemory();
        await tokenStore.clear();
      }
      return false;
    }

    if (response.statusCode != 200) {
      return false;
    }

    try {
      final data = decodeObject(response);
      final accessToken = data['access_token']?.toString();
      if (accessToken == null || accessToken.isEmpty) {
        return false;
      }
      await persistTokens(
        AuthTokens(
          accessToken: accessToken,
          // El backend actual no rota el refresh token; se conserva el vigente.
          refreshToken: data['refresh_token']?.toString() ?? refreshToken,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getJson(Uri uri) async {
    final response = await client.get(uri, headers: jsonHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        errorMessageFromResponse(
          response,
          'La API no respondio correctamente',
        ),
        response.statusCode,
      );
    }

    return decodeObject(response);
  }

  Future<Map<String, dynamic>> getAuthorizedJson(
    Uri uri, {
    required String fallback,
  }) {
    return authorizedJson(
      request: (token) => client.get(uri, headers: authorizedHeaders(token)),
      fallback: fallback,
    );
  }

  Future<List<dynamic>> getAuthorizedList(
    Uri uri, {
    required String fallback,
  }) async {
    final token = await ensureAccessToken();
    var response = await client.get(uri, headers: authorizedHeaders(token));

    if (response.statusCode == 401 &&
        await refreshAccessToken(staleToken: token)) {
      response = await client.get(
        uri,
        headers: authorizedHeaders(await ensureAccessToken()),
      );
    }

    if (response.statusCode == 401) {
      throw sessionRefreshFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ApiException('Respuesta inesperada del historial');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> postAuthorizedJson(
    Uri uri, {
    Object? body,
    required String fallback,
    bool allowEmptyJson = false,
  }) {
    return authorizedJson(
      request: (token) => client.post(
        uri,
        headers: authorizedHeaders(token),
        body: body == null ? null : jsonEncode(body),
      ),
      fallback: fallback,
      allowEmptyJson: allowEmptyJson,
    );
  }

  Future<Map<String, dynamic>> postPublicJson(
    Uri uri, {
    required Object body,
    required String fallback,
  }) async {
    final response = await client.post(
      uri,
      headers: jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }

    return decodeObject(response);
  }

  Future<Map<String, dynamic>> patchAuthorizedJson(
    Uri uri, {
    required Object body,
    required String fallback,
  }) {
    return authorizedJson(
      request: (token) => client.patch(
        uri,
        headers: authorizedHeaders(token),
        body: jsonEncode(body),
      ),
      fallback: fallback,
    );
  }

  Future<Map<String, dynamic>> putAuthorizedJson(
    Uri uri, {
    required Object body,
    required String fallback,
  }) {
    return authorizedJson(
      request: (token) => client.put(
        uri,
        headers: authorizedHeaders(token),
        body: jsonEncode(body),
      ),
      fallback: fallback,
    );
  }

  Future<void> deleteAuthorized(Uri uri, {required String fallback}) async {
    final token = await ensureAccessToken();
    var response = await client.delete(uri, headers: authorizedHeaders(token));

    if (response.statusCode == 401 &&
        await refreshAccessToken(staleToken: token)) {
      response = await client.delete(
        uri,
        headers: authorizedHeaders(await ensureAccessToken()),
      );
    }

    if (response.statusCode == 401) {
      throw sessionRefreshFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> authorizedJson({
    required Future<http.Response> Function(String token) request,
    required String fallback,
    bool allowEmptyJson = false,
  }) async {
    final token = await ensureAccessToken();
    var response = await request(token);

    if (response.statusCode == 401 &&
        await refreshAccessToken(staleToken: token)) {
      response = await request(await ensureAccessToken());
    }

    if (response.statusCode == 401) {
      throw sessionRefreshFailure();
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }

    return decodeObject(response, allowEmptyJson: allowEmptyJson);
  }

  Map<String, String> authorizedHeaders(String token) {
    return {...jsonHeaders, 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> decodeObject(
    http.Response response, {
    bool allowEmptyJson = false,
  }) {
    final body = response.body.trim();
    if (allowEmptyJson && (body.isEmpty || body == 'null')) {
      return {};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException('Respuesta inesperada del backend');
  }

  List<T> decodeList<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final items = data['items'];
    if (items is! List) {
      throw const ApiException('Respuesta inesperada del backend');
    }
    return items
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  String errorMessageFromResponse(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          return 'Revisa los datos ingresados';
        }
      }
    } catch (_) {
      return fallback;
    }

    return fallback;
  }
}

class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'].toString(),
      refreshToken: json['refresh_token'].toString(),
    );
  }

  final String accessToken;
  final String refreshToken;
}

abstract class TokenStore {
  Future<AuthTokens?> read();
  Future<void> save(AuthTokens tokens);
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'uleammed_access_token';
  static const _refreshTokenKey = 'uleammed_refresh_token';

  @override
  Future<AuthTokens?> read() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) {
      return null;
    }

    return AuthTokens(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> save(AuthTokens tokens) async {
    await _storage.write(key: _accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: _refreshTokenKey, value: tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

/// Un id de backend persistido es un entero positivo cuya representacion en
/// texto no tiene ceros ni caracteres extra (a diferencia de los ids
/// generados localmente, que son UUIDs u otros strings no numericos).
bool isPersistedBackendId(String id) {
  final parsed = int.tryParse(id);
  return parsed != null && parsed > 0 && id == parsed.toString();
}

class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message (HTTP $statusCode)';
  }
}
