import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uleam_med/services/api_service.dart';
import 'package:uleam_med/services/local_store.dart';

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

class _MemoryJsonStore implements JsonStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  group('ApiService session handling', () {
    test('restores a valid stored session', () async {
      final tokenStore = _MemoryTokenStore(
        const AuthTokens(accessToken: 'access-ok', refreshToken: 'refresh-ok'),
      );
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        localStore: localStore,
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
        final localStore = LocalStore(jsonStore: _MemoryJsonStore());
        final api = ApiService(
          baseUrl: 'http://localhost:8000',
          tokenStore: tokenStore,
          localStore: localStore,
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
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        localStore: localStore,
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

  group('ApiService offline data', () {
    test('records a pending local confirmation without backend', () async {
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      await localStore.upsertMedication(
        const MedicationItem(
          id: 'omeprazol',
          name: 'Omeprazol',
          dose: '20 mg',
          time: '14:00',
          taken: false,
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: _MemoryTokenStore(),
        localStore: localStore,
        client: MockClient((request) async {
          return _jsonResponse({'detail': 'No autorizado'}, statusCode: 401);
        }),
      );

      final medications = await api.listMedications();
      expect(medications, hasLength(1));

      final result = await api.recordMedicationStatus(
        'omeprazol',
        DoseStatus.taken,
      );
      final confirmations = await api.listDoseConfirmations();

      expect(result.medication.taken, isTrue);
      expect(confirmations, hasLength(1));
      expect(confirmations.first.status, DoseStatus.taken);
      expect(await api.pendingSyncCount(), greaterThanOrEqualTo(1));
    });

    test('does not auto-seed medications for new accounts', () async {
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: _MemoryTokenStore(
          const AuthTokens(accessToken: 'access-ok', refreshToken: 'refresh-ok'),
        ),
        localStore: localStore,
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/medications') {
            return _jsonResponse({'items': []});
          }
          return _jsonResponse({'detail': 'No autorizado'}, statusCode: 401);
        }),
      );

      final medications = await api.listMedications();

      expect(medications, isEmpty);
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
