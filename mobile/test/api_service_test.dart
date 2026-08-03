import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uleam_med/models/app_role.dart';
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
      expect(session!.user.email, 'roberto@uleammed.test');
      expect(session.user.fullName, 'Roberto Andrade');
      expect(session.user.role, AppRole.patient);
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

    test('registers a caregiver account explicitly', () async {
      final tokenStore = _MemoryTokenStore();
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        localStore: LocalStore(jsonStore: _MemoryJsonStore()),
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/auth/register') {
            expect(jsonDecode(request.body)['account_type'], 'caregiver');
            return _jsonResponse({
              ..._userJson(fullName: 'Carla Cuidadora'),
              'role': 'caregiver',
            }, statusCode: 201);
          }
          if (request.url.path == '/api/v1/auth/login') {
            return _jsonResponse({
              'access_token': 'access-ok',
              'refresh_token': 'refresh-ok',
            });
          }
          if (request.url.path == '/health') {
            return _jsonResponse({'environment': 'test'});
          }
          if (request.url.path == '/api/v1/users/me') {
            return _jsonResponse({
              ..._userJson(fullName: 'Carla Cuidadora'),
              'role': 'caregiver',
            });
          }
          return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
        }),
      );

      final session = await api.register(
        email: 'carla@uleammed.test',
        password: 'clave-segura-123',
        fullName: 'Carla Cuidadora',
        accountType: AppRole.caregiver,
      );

      expect(session.user.role, AppRole.caregiver);
      expect(tokenStore.tokens?.refreshToken, 'refresh-ok');
    });
  });

  group('ApiService caregiving', () {
    test(
      'maps invitation, links, patients and read-only medications',
      () async {
        final api = ApiService(
          baseUrl: 'http://localhost:8000',
          tokenStore: _MemoryTokenStore(
            const AuthTokens(
              accessToken: 'access-ok',
              refreshToken: 'refresh-ok',
            ),
          ),
          localStore: LocalStore(jsonStore: _MemoryJsonStore()),
          client: MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer access-ok');
            if (request.url.path == '/api/v1/caregiving/invitations' &&
                request.method == 'POST') {
              return _jsonResponse({
                'id': 7,
                'code': 'ABCD-2345',
                'expires_at': '2026-07-09T12:00:00Z',
              }, statusCode: 201);
            }
            if (request.url.path == '/api/v1/caregiving/invitations/redeem') {
              expect(jsonDecode(request.body), {'code': 'ABCD-2345'});
              return _jsonResponse(_linkJson());
            }
            if (request.url.path == '/api/v1/caregiving/links') {
              return _jsonResponse({
                'items': [_linkJson()],
              });
            }
            if (request.url.path == '/api/v1/caregiving/patients') {
              return _jsonResponse({
                'items': [
                  {'id': 1, 'full_name': 'Roberto Andrade'},
                ],
              });
            }
            if (request.url.path ==
                '/api/v1/caregiving/patients/1/medications') {
              return _jsonResponse({
                'items': [
                  {
                    'id': '9',
                    'name': 'Losartan',
                    'dose': '50 mg',
                    'time': '08:00',
                    'taken': false,
                    'frequency': 'Diario',
                    'duration': '',
                    'instructions': '',
                    'isImportant': true,
                  },
                ],
              });
            }
            return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
          }),
        );

        final invitation = await api.createCaregiverInvitation();
        final redeemed = await api.redeemCaregiverInvitation('ABCD-2345');
        final links = await api.listCaregivingLinks();
        final patients = await api.listCaregiverPatients();
        final medications = await api.listCaregiverPatientMedications(1);

        expect(invitation.code, 'ABCD-2345');
        expect(redeemed.status, CaregiverLinkStatus.pending);
        expect(links, hasLength(1));
        expect(patients.single.fullName, 'Roberto Andrade');
        expect(medications.single.name, 'Losartan');
      },
    );

    test('creates caregiver patient medication through sync queue', () async {
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: _MemoryTokenStore(
          const AuthTokens(
            accessToken: 'access-ok',
            refreshToken: 'refresh-ok',
          ),
        ),
        localStore: LocalStore(jsonStore: _MemoryJsonStore()),
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer access-ok');
          if (request.url.path ==
                  '/api/v1/caregiving/patients/3/medications/sync' &&
              request.method == 'POST') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final actions = body['actions'] as List<dynamic>;
            final action = actions.single as Map<String, dynamic>;
            final payload = action['payload'] as Map<String, dynamic>;
            expect(action['operation_type'], 'create_medication');
            expect(payload['name'], 'Aspirina');
            final medication = {
              'id': '42',
              'name': 'Aspirina',
              'dose': '100 mg',
              'time': '20:00',
              'taken': false,
              'frequency': 'Diario',
              'duration': '',
              'instructions': '',
              'isImportant': true,
              'schedule': payload['schedule'],
              'clientMedicationId': action['client_medication_id'],
            };
            return _jsonResponse({
              'results': [
                {
                  'client_operation_id': action['client_operation_id'],
                  'client_medication_id': action['client_medication_id'],
                  'status': 'synced',
                  'medication': medication,
                },
              ],
              'items': [medication],
              'pending_conflicts': [],
            });
          }
          return _jsonResponse({'detail': 'No permitido'}, statusCode: 405);
        }),
      );

      final saved = await api.saveCaregiverPatientMedication(
        3,
        MedicationItem(
          id: 'aspirina-1739123456789',
          name: 'Aspirina',
          dose: '100 mg',
          doseAmount: 100,
          doseUnit: 'mg',
          time: '20:00',
          taken: false,
        ),
      );

      expect(saved.id, '42');
      expect(saved.name, 'Aspirina');
    });

    test(
      'prefers backend medication updates from caregiver over stale cache',
      () async {
        final localStore = LocalStore(jsonStore: _MemoryJsonStore());
        await localStore.saveActiveUserId('1');
        await localStore.upsertMedication(
          const MedicationItem(
            id: '7',
            name: 'verdesol',
            dose: '1500 mg',
            time: '08:00',
            taken: false,
            instructions: 'tomar con agua',
            syncStatus: SyncStatus.synced,
          ),
        );
        final api = ApiService(
          baseUrl: 'http://localhost:8000',
          tokenStore: _MemoryTokenStore(
            const AuthTokens(
              accessToken: 'access-ok',
              refreshToken: 'refresh-ok',
            ),
          ),
          localStore: localStore,
          client: MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer access-ok');
            if (request.url.path == '/api/v1/medications') {
              return _jsonResponse({
                'items': [
                  {
                    'id': '7',
                    'name': 'verdesol',
                    'dose': '1500 mg',
                    'time': '08:00',
                    'taken': true,
                    'frequency': 'Diario',
                    'duration': 'Permanente',
                    'instructions': 'tomar con mucha agua',
                    'isImportant': true,
                    'photoAvailable': false,
                    'schedule': {
                      'mode': 'fixed_times',
                      'times': ['08:00'],
                      'weekdays': [1, 2, 3, 4, 5, 6, 7],
                      'start_date': '2026-07-09',
                    },
                  },
                ],
              });
            }
            if (request.url.path == '/api/v1/medications/sync-conflicts') {
              return _jsonResponse({'items': []});
            }
            return _jsonResponse({'detail': 'No permitido'}, statusCode: 405);
          }),
        );

        final medications = await api.listMedications();

        expect(medications, hasLength(1));
        expect(medications.first.instructions, 'tomar con mucha agua');
        expect(medications.first.taken, isTrue);
      },
    );
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
          const AuthTokens(
            accessToken: 'access-ok',
            refreshToken: 'refresh-ok',
          ),
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

    test('merges backend dose events with local history', () async {
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      await localStore.addDoseConfirmation(
        DoseConfirmation(
          id: 'local-1',
          medicationId: '5',
          medicationName: 'Omeprazol',
          status: DoseStatus.taken,
          recordedAt: DateTime(2026, 7, 9, 14),
          syncStatus: SyncStatus.pending,
          scheduledAt: DateTime(2026, 7, 9, 14),
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: _MemoryTokenStore(
          const AuthTokens(
            accessToken: 'access-ok',
            refreshToken: 'refresh-ok',
          ),
        ),
        localStore: localStore,
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/medications/dose-events') {
            return http.Response(
              jsonEncode([
                {
                  'id': 99,
                  'medication_id': 5,
                  'medication_name': 'Omeprazol',
                  'status': 'taken',
                  'acted_at': '2026-07-08T12:00:00.000Z',
                  'scheduled_at': '2026-07-08T12:00:00.000Z',
                  'sequence_number': 1,
                },
              ]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return _jsonResponse({'detail': 'No permitido'}, statusCode: 405);
        }),
      );

      final confirmations = await api.listDoseConfirmations();

      expect(confirmations, hasLength(2));
      expect(
        confirmations.map((item) => item.id),
        containsAll(['local-1', '99']),
      );
    });

    test(
      'syncs appointments through backend for patient and caregiver',
      () async {
        final localStore = LocalStore(jsonStore: _MemoryJsonStore());
        await localStore.saveActiveUserId('1');
        final api = ApiService(
          baseUrl: 'http://localhost:8000',
          tokenStore: _MemoryTokenStore(
            const AuthTokens(
              accessToken: 'access-ok',
              refreshToken: 'refresh-ok',
            ),
          ),
          localStore: localStore,
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/appointments' &&
                request.method == 'GET') {
              return _jsonResponse({
                'items': [
                  {
                    'id': '12',
                    'doctor': 'Dr. Perez',
                    'specialty': 'Cardiologia',
                    'location': 'Hospital',
                    'notes': '',
                    'completed': false,
                    'reminder': 'none',
                    'scheduledAt': '2026-12-15T15:00:00.000Z',
                  },
                ],
              });
            }
            if (request.url.path ==
                    '/api/v1/caregiving/patients/7/appointments' &&
                request.method == 'GET') {
              return _jsonResponse({'items': []});
            }
            return _jsonResponse({'detail': 'No permitido'}, statusCode: 405);
          }),
        );

        final appointments = await api.listAppointments();

        expect(appointments, hasLength(1));
        expect(appointments.first.doctor, 'Dr. Perez');
      },
    );

    test('replaces stale local appointments with backend data', () async {
      final localStore = LocalStore(jsonStore: _MemoryJsonStore());
      await localStore.saveActiveUserId('1');
      await localStore.upsertAppointment(
        Appointment(
          id: 'cita-local-vieja',
          doctor: 'Dr. Viejo',
          specialty: 'General',
          date: '01 Ene 2020',
          time: '08:00',
          location: '',
          scheduledAt: DateTime(2020, 1, 1, 8),
          syncStatus: SyncStatus.synced,
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: _MemoryTokenStore(
          const AuthTokens(
            accessToken: 'access-ok',
            refreshToken: 'refresh-ok',
          ),
        ),
        localStore: localStore,
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/appointments' &&
              request.method == 'GET') {
            return _jsonResponse({
              'items': [
                {
                  'id': '21',
                  'doctor': 'Dra. Lopez',
                  'specialty': 'Dermatologia',
                  'location': 'Clinica',
                  'notes': '',
                  'completed': false,
                  'reminder': 'none',
                  'scheduledAt': '2026-12-20T10:00:00.000Z',
                },
              ],
            });
          }
          return _jsonResponse({'detail': 'No permitido'}, statusCode: 405);
        }),
      );

      final appointments = await api.listAppointments();

      expect(appointments, hasLength(1));
      expect(appointments.first.id, '21');
      expect(appointments.first.doctor, 'Dra. Lopez');
    });
  });

  group('ApiService token refresh', () {
    test('varios 401 simultaneos comparten un unico refresh', () async {
      var refreshCalls = 0;
      var rejectedProfileCalls = 0;
      final tokenStore = _MemoryTokenStore(
        const AuthTokens(
          accessToken: 'access-vencido',
          refreshToken: 'refresh-ok',
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        localStore: LocalStore(jsonStore: _MemoryJsonStore()),
        client: MockClient((request) async {
          if (request.url.path == '/health') {
            return _jsonResponse({'environment': 'test'});
          }
          if (request.url.path == '/api/v1/auth/refresh') {
            refreshCalls++;
            // Latencia para que ambas peticiones coincidan en el mismo refresh.
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return _jsonResponse({'access_token': 'access-nuevo'});
          }
          if (request.url.path == '/api/v1/users/me') {
            if (request.headers['authorization'] == 'Bearer access-vencido') {
              rejectedProfileCalls++;
              return _jsonResponse(
                {'detail': 'Token expirado'},
                statusCode: 401,
              );
            }
            return _jsonResponse(_userJson(fullName: 'Roberto Andrade'));
          }
          return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
        }),
      );

      final sessions = await Future.wait([
        api.loadAppSession(),
        api.loadAppSession(),
      ]);

      expect(sessions, hasLength(2));
      expect(rejectedProfileCalls, 2);
      expect(
        refreshCalls,
        1,
        reason: 'el single-flight debe colapsar los refresh concurrentes',
      );
      expect(tokenStore.tokens?.accessToken, 'access-nuevo');
      expect(tokenStore.wasCleared, isFalse);
    });

    test('un 503 al renovar no cierra la sesion del usuario', () async {
      final tokenStore = _MemoryTokenStore(
        const AuthTokens(
          accessToken: 'access-vencido',
          refreshToken: 'refresh-ok',
        ),
      );
      final api = ApiService(
        baseUrl: 'http://localhost:8000',
        tokenStore: tokenStore,
        localStore: LocalStore(jsonStore: _MemoryJsonStore()),
        client: MockClient((request) async {
          if (request.url.path == '/health') {
            return _jsonResponse({'environment': 'test'});
          }
          if (request.url.path == '/api/v1/auth/refresh') {
            return _jsonResponse(
              {'detail': 'Servicio no disponible'},
              statusCode: 503,
            );
          }
          if (request.url.path == '/api/v1/users/me') {
            return _jsonResponse({'detail': 'Token expirado'}, statusCode: 401);
          }
          return _jsonResponse({'detail': 'No encontrado'}, statusCode: 404);
        }),
      );

      await expectLater(api.loadAppSession(), throwsA(isA<ApiException>()));
      expect(
        tokenStore.wasCleared,
        isFalse,
        reason: 'una caida del backend no debe borrar los tokens del paciente',
      );
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
    'email': 'roberto@uleammed.test',
    'full_name': fullName,
    'is_active': true,
    'role': 'patient',
  };
}

Map<String, dynamic> _linkJson() {
  return {
    'id': 4,
    'status': 'pending',
    'counterpart_user_id': 1,
    'counterpart_name': 'Roberto Andrade',
    'counterpart_email_masked': 'r***@uleammed.test',
    'requested_at': '2026-07-08T12:00:00Z',
    'decided_at': null,
    'revoked_at': null,
  };
}
