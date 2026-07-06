import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uleam_med/services/api_service.dart';

class _MemoryTokenStore implements TokenStore {
  AuthTokens? tokens;
  bool wasCleared = false;

  _MemoryTokenStore([this.tokens]);

  @override
  Future<AuthTokens?> read() async => tokens;

  @override
  Future<void> save(AuthTokens tokens) async {
    this.tokens = tokens;
    wasCleared = false;
  }

  @override
  Future<void> clear() async {
    tokens = null;
    wasCleared = true;
  }
}

void main() {
  group('ApiService session handling', () {
    test('restores a valid stored session', () async {
      final tokenStore = _MemoryTokenStore(
        const AuthTokens(accessToken: 'access-ok', refreshToken: 'refresh-ok'),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        client: MockClient((request) async {
          if (request.url.path == '/health') {
            return _jsonResponse({'environment': 'test'});
          }
          if (request.url.path == '/api/v1/users/me') {
            expect(request.headers['authorization'], 'Bearer access-ok');
            return _jsonResponse(_userJson(fullName: 'Roberto Andrade'));
          }
          return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
        }),
      );

      final session = await api.restoreSession();

      expect(session, isNotNull);
      expect(session!.user.email, 'roberto@uleammed.demo');
      expect(session.user.fullName, 'Roberto Andrade');
    });

    test(
      'refreshes access token once when stored access token expired',
      () async {
        final tokenStore = _MemoryTokenStore(
          const AuthTokens(
            accessToken: 'access-expired',
            refreshToken: 'refresh-ok',
          ),
        );
        var profileCalls = 0;
        final api = ApiService(
          baseUrl: 'http://localhost:8000',
          tokenStore: tokenStore,
          client: MockClient((request) async {
            if (request.url.path == '/health') {
              return _jsonResponse({'environment': 'test'});
            }
            if (request.url.path == '/api/v1/users/me') {
              profileCalls++;
              final auth = request.headers['authorization'];
              if (auth == 'Bearer access-expired') {
                return _jsonResponse({
                  'detail': 'Token vencido',
                }, statusCode: 401);
              }
              expect(auth, 'Bearer access-renewed');
              return _jsonResponse(_userJson(fullName: 'Roberto Renovado'));
            }
            if (request.url.path == '/api/v1/auth/refresh') {
              expect(jsonDecode(request.body), {'refresh_token': 'refresh-ok'});
              return _jsonResponse({'access_token': 'access-renewed'});
            }
            return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
          }),
        );

        final session = await api.restoreSession();

        expect(session!.user.fullName, 'Roberto Renovado');
        expect(profileCalls, 2);
        expect(tokenStore.tokens!.accessToken, 'access-renewed');
        expect(tokenStore.tokens!.refreshToken, 'refresh-ok');
      },
    );

    test('clears session when refresh token is invalid', () async {
      final tokenStore = _MemoryTokenStore(
        const AuthTokens(
          accessToken: 'access-expired',
          refreshToken: 'refresh-expired',
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        client: MockClient((request) async {
          if (request.url.path == '/health') {
            return _jsonResponse({'environment': 'test'});
          }
          if (request.url.path == '/api/v1/users/me') {
            return _jsonResponse({'detail': 'Token vencido'}, statusCode: 401);
          }
          if (request.url.path == '/api/v1/auth/refresh') {
            return _jsonResponse({
              'detail': 'Refresh token invalido o expirado',
            }, statusCode: 401);
          }
          return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
        }),
      );

      final session = await api.restoreSession();

      expect(session, isNull);
      expect(tokenStore.wasCleared, isTrue);
      expect(tokenStore.tokens, isNull);
    });
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _userJson({required String fullName}) {
  return {
    'id': 1,
    'email': 'roberto@uleammed.demo',
    'full_name': fullName,
    'is_active': true,
  };
}
