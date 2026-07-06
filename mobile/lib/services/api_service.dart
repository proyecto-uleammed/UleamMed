import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/local_models.dart';
import 'local_store.dart';
import 'sync_service.dart';

export '../models/local_models.dart';

abstract class UleamMedApi {
  Future<DemoSession?> restoreSession();
  Future<DemoSession> login({required String email, required String password});
  Future<DemoSession> register({
    required String email,
    required String password,
    required String fullName,
  });
  Future<DemoSession> startDemoSession();
  Future<DemoSession> loadDemoSession();
  Future<DemoSession> updateProfile({required String fullName});
  Future<String> requestPasswordReset({required String email});
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });
  Future<void> logout();
  Future<MedicalProfile> loadMedicalProfile();
  Future<MedicalProfile> saveMedicalProfile(MedicalProfile profile);
  Future<List<MedicationItem>> listMedications();
  Future<MedicationItem> saveMedication(MedicationItem medication);
  Future<void> deleteMedication(String medicationId);
  Future<MedicationMarkResult> markMedicationTaken(String medicationId);
  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  );
  Future<List<DoseConfirmation>> listDoseConfirmations();
  Future<List<Appointment>> listAppointments();
  Future<List<EmergencyContact>> listEmergencyContacts();
  Future<EmergencyContact> saveEmergencyContact(EmergencyContact contact);
  Future<void> deleteEmergencyContact(String contactId);
  Future<List<HealthEntry>> listHealthEntries();
  Future<HealthEntry> saveHealthEntry(HealthEntry entry);
  Future<void> deleteHealthEntry(String entryId);
  Future<int> pendingSyncCount();
  Future<SyncSummary> synchronizePendingChanges();
}

class ApiService implements UleamMedApi {
  ApiService({
    http.Client? client,
    String? baseUrl,
    TokenStore? tokenStore,
    LocalStore? localStore,
  })
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl,
      _tokenStore = tokenStore ?? SecureTokenStore(),
      _localStore = localStore ?? LocalStore() {
    _syncService = SyncService(localStore: _localStore);
  }

  final http.Client _client;
  final String _baseUrl;
  final TokenStore _tokenStore;
  final LocalStore _localStore;
  late final SyncService _syncService;
  String? _accessToken;
  String? _refreshToken;

  static const _demoEmail = 'roberto@uleammed.demo';
  static const _demoPassword = 'clave-segura-123';
  static const _demoName = 'Roberto Andrade';

  static String get _defaultBaseUrl {
    const configuredUrl = String.fromEnvironment('ULEAMMED_API_URL');
    if (configuredUrl.isNotEmpty) {
      return configuredUrl;
    }

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

  @override
  Future<DemoSession?> restoreSession() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) {
      return null;
    }

    _setTokensInMemory(tokens);
    try {
      return await loadDemoSession();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<DemoSession> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _loginUser(email: email, password: password);
    await _persistTokens(tokens);
    return loadDemoSession();
  }

  @override
  Future<DemoSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(
        _errorMessageFromResponse(response, 'No se pudo crear la cuenta'),
        response.statusCode,
      );
    }

    return login(email: email, password: password);
  }

  @override
  Future<DemoSession> startDemoSession() async {
    await _ensureDemoUser();
    final tokens = await _loginUser(email: _demoEmail, password: _demoPassword);
    await _persistTokens(tokens);
    return loadDemoSession();
  }

  @override
  Future<DemoSession> loadDemoSession() async {
    final health = await _getJson(Uri.parse('$_baseUrl/health'));
    final user = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/users/me'),
      fallback: 'No se pudo cargar el perfil',
    );

    return DemoSession(
      apiUrl: _baseUrl,
      environment: health['environment']?.toString() ?? 'development',
      user: DemoUser.fromJson(user),
    );
  }

  @override
  Future<DemoSession> updateProfile({required String fullName}) async {
    await _patchAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/users/me'),
      body: {'full_name': fullName.trim()},
      fallback: 'No se pudo actualizar el perfil',
    );

    return loadDemoSession();
  }

  @override
  Future<String> requestPasswordReset({required String email}) async {
    final data = await _postPublicJson(
      Uri.parse('$_baseUrl/api/v1/auth/forgot-password'),
      body: {'email': email.trim()},
      fallback: 'No se pudo solicitar la recuperacion',
    );
    return data['message']?.toString() ??
        'Si el correo existe, enviaremos instrucciones para restablecer la contrasena.';
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _postPublicJson(
      Uri.parse('$_baseUrl/api/v1/auth/reset-password'),
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

  @override
  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    await _tokenStore.clear();
  }

  @override
  Future<MedicalProfile> loadMedicalProfile() {
    return _localStore.readMedicalProfile();
  }

  @override
  Future<MedicalProfile> saveMedicalProfile(MedicalProfile profile) async {
    await _localStore.saveMedicalProfile(profile);
    return _localStore.readMedicalProfile();
  }

  @override
  Future<List<MedicationItem>> listMedications() async {
    final localItems = await _localStore.readMedications();

    try {
      final backendItems = await _loadBackendMedications();
      if (localItems.isEmpty) {
        await _localStore.saveMedications(backendItems);
        return backendItems;
      }
      final merged = _mergeMedications(localItems, backendItems);
      await _localStore.saveMedications(merged);
      return merged;
    } catch (_) {
      if (localItems.isNotEmpty) {
        return localItems;
      }

      final demoItems = MedicationItem.demoList();
      await _localStore.saveMedications(demoItems);
      return demoItems;
    }
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    return recordMedicationStatus(medicationId, DoseStatus.taken);
  }

  @override
  Future<MedicationItem> saveMedication(MedicationItem medication) {
    return _localStore.upsertMedication(
      medication.copyWith(syncStatus: SyncStatus.pending),
    );
  }

  @override
  Future<void> deleteMedication(String medicationId) {
    return _localStore.deleteMedication(medicationId);
  }

  @override
  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  ) async {
    final medications = await listMedications();
    final medication = medications.firstWhere(
      (item) => item.id == medicationId,
      orElse: () => throw const ApiException('Medicamento no encontrado'),
    );
    final updated = medication.copyWith(
      taken: status == DoseStatus.taken ? true : medication.taken,
      syncStatus: SyncStatus.pending,
    );
    await _localStore.upsertMedication(updated);
    await _localStore.addDoseConfirmation(
      DoseConfirmation(
        id: '${medication.id}-${DateTime.now().microsecondsSinceEpoch}',
        medicationId: medication.id,
        medicationName: medication.name,
        status: status,
        recordedAt: DateTime.now(),
      ),
    );

    final localResult = await _medicationResultFor(updated.id);
    if (status != DoseStatus.taken) {
      return localResult;
    }

    try {
      final data = await _postAuthorizedJson(
        Uri.parse('$_baseUrl/api/v1/medications/$medicationId/take'),
        fallback: 'No se pudo marcar el medicamento',
      );
      final backendResult = MedicationMarkResult.fromJson(data);
      await _localStore.upsertMedication(
        backendResult.medication.copyWith(syncStatus: SyncStatus.synced),
      );
      return backendResult;
    } catch (_) {
      return localResult;
    }
  }

  @override
  Future<List<DoseConfirmation>> listDoseConfirmations() {
    return _localStore.readDoseConfirmations();
  }

  @override
  Future<List<Appointment>> listAppointments() async {
    final appointments = await _localStore.readAppointments();
    if (appointments.isNotEmpty) {
      return appointments;
    }
    const demoAppointments = [
      Appointment(
        id: 'cita-general',
        doctor: 'Dra. Maria Gonzalez',
        specialty: 'Medicina General',
        date: '28 Jun 2026',
        time: '10:30',
        location: 'Centro de Salud Norte',
      ),
      Appointment(
        id: 'cita-cardio',
        doctor: 'Dr. Carlos Ruiz',
        specialty: 'Cardiologia',
        date: '05 Jul 2026',
        time: '15:00',
        location: 'Hospital Regional',
      ),
    ];
    await _localStore.saveAppointments(demoAppointments);
    return demoAppointments;
  }

  @override
  Future<List<EmergencyContact>> listEmergencyContacts() async {
    final contacts = await _localStore.readEmergencyContacts();
    if (contacts.isNotEmpty) {
      return contacts;
    }
    const demoContacts = [
      EmergencyContact(
        id: '911',
        name: 'Emergencias',
        phone: '911',
        relationship: 'Emergencia',
        isPrimary: true,
      ),
      EmergencyContact(
        id: 'hija',
        name: 'Maria',
        phone: '555-1234',
        relationship: 'Hija',
      ),
      EmergencyContact(
        id: 'medico',
        name: 'Dr. Gonzalez',
        phone: '555-9012',
        relationship: 'Medico',
      ),
    ];
    await _localStore.saveEmergencyContacts(demoContacts);
    return demoContacts;
  }

  @override
  Future<EmergencyContact> saveEmergencyContact(EmergencyContact contact) {
    return _localStore.upsertEmergencyContact(contact);
  }

  @override
  Future<void> deleteEmergencyContact(String contactId) {
    return _localStore.deleteEmergencyContact(contactId);
  }

  @override
  Future<List<HealthEntry>> listHealthEntries() {
    return _localStore.readHealthEntries();
  }

  @override
  Future<HealthEntry> saveHealthEntry(HealthEntry entry) {
    return _localStore.upsertHealthEntry(entry);
  }

  @override
  Future<void> deleteHealthEntry(String entryId) {
    return _localStore.deleteHealthEntry(entryId);
  }

  @override
  Future<int> pendingSyncCount() {
    return _localStore.pendingSyncCount();
  }

  @override
  Future<SyncSummary> synchronizePendingChanges() {
    return _syncService.synchronizePending();
  }

  Future<List<MedicationItem>> _loadBackendMedications() async {
    final data = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/medications'),
      fallback: 'No se pudieron cargar los medicamentos',
    );

    final items = data['items'];
    if (items is! List) {
      throw const ApiException('Respuesta inesperada de medicamentos');
    }

    return items
        .whereType<Map>()
        .map((json) => MedicationItem.fromJson(Map<String, dynamic>.from(json)).copyWith(
              syncStatus: SyncStatus.synced,
            ))
        .toList();
  }

  List<MedicationItem> _mergeMedications(
    List<MedicationItem> localItems,
    List<MedicationItem> backendItems,
  ) {
    final byId = <String, MedicationItem>{
      for (final item in backendItems) item.id: item,
    };
    for (final local in localItems) {
      if (local.syncStatus == SyncStatus.pending) {
        byId[local.id] = local;
      } else {
        final backend = byId[local.id];
        byId[local.id] = (backend ?? local).copyWith(
          frequency: local.frequency,
          duration: local.duration,
          instructions: local.instructions,
          isImportant: local.isImportant,
        );
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<MedicationMarkResult> _medicationResultFor(String medicationId) async {
    final medications = await _localStore.readMedications();
    final medication = medications.firstWhere(
      (item) => item.id == medicationId,
      orElse: () => throw const ApiException('Medicamento no encontrado'),
    );
    final takenCount = medications.where((item) => item.taken).length;
    return MedicationMarkResult(
      medication: medication,
      takenCount: takenCount,
      totalCount: medications.length,
    );
  }

  Future<String> _ensureAccessToken() async {
    if (_accessToken != null) {
      return _accessToken!;
    }

    final tokens = await _tokenStore.read();
    if (tokens != null) {
      _setTokensInMemory(tokens);
      return tokens.accessToken;
    }

    throw const ApiException('Sesion no iniciada', 401);
  }

  Future<void> _ensureDemoUser() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': _demoEmail,
        'password': _demoPassword,
        'full_name': _demoName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 409) {
      return;
    }

    throw ApiException(
      _errorMessageFromResponse(
        response,
        'No se pudo preparar el usuario demo',
      ),
      response.statusCode,
    );
  }

  Future<AuthTokens> _loginUser({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessageFromResponse(response, 'No se pudo iniciar sesion'),
        response.statusCode,
      );
    }

    return AuthTokens.fromJson(_decodeObject(response));
  }

  Future<void> _persistTokens(AuthTokens tokens) async {
    _setTokensInMemory(tokens);
    await _tokenStore.save(tokens);
  }

  void _setTokensInMemory(AuthTokens tokens) {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
  }

  Future<bool> _refreshAccessToken() async {
    var refreshToken = _refreshToken;
    if (refreshToken == null) {
      final stored = await _tokenStore.read();
      if (stored == null) {
        return false;
      }
      _setTokensInMemory(stored);
      refreshToken = stored.refreshToken;
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/refresh'),
      headers: _jsonHeaders,
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode != 200) {
      await logout();
      return false;
    }

    final data = _decodeObject(response);
    final refreshedTokens = AuthTokens(
      accessToken: data['access_token'].toString(),
      refreshToken: refreshToken,
    );
    await _persistTokens(refreshedTokens);
    return true;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri, headers: _jsonHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessageFromResponse(
          response,
          'La API no respondio correctamente',
        ),
        response.statusCode,
      );
    }

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> _getAuthorizedJson(
    Uri uri, {
    required String fallback,
  }) {
    return _authorizedJson(
      request: (token) => _client.get(uri, headers: _authorizedHeaders(token)),
      fallback: fallback,
    );
  }

  Future<Map<String, dynamic>> _postAuthorizedJson(
    Uri uri, {
    Object? body,
    required String fallback,
  }) {
    return _authorizedJson(
      request: (token) => _client.post(
        uri,
        headers: _authorizedHeaders(token),
        body: body == null ? null : jsonEncode(body),
      ),
      fallback: fallback,
    );
  }

  Future<Map<String, dynamic>> _postPublicJson(
    Uri uri, {
    required Object body,
    required String fallback,
  }) async {
    final response = await _client.post(
      uri,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }

    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> _patchAuthorizedJson(
    Uri uri, {
    required Object body,
    required String fallback,
  }) {
    return _authorizedJson(
      request: (token) => _client.patch(
        uri,
        headers: _authorizedHeaders(token),
        body: jsonEncode(body),
      ),
      fallback: fallback,
    );
  }

  Future<Map<String, dynamic>> _authorizedJson({
    required Future<http.Response> Function(String token) request,
    required String fallback,
  }) async {
    final token = await _ensureAccessToken();
    var response = await request(token);

    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await request(await _ensureAccessToken());
    }

    if (response.statusCode == 401) {
      await logout();
      throw const ApiException(
        'Sesion expirada, inicia sesion nuevamente',
        401,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _errorMessageFromResponse(response, fallback),
        response.statusCode,
      );
    }

    return _decodeObject(response);
  }

  Map<String, String> _authorizedHeaders(String token) {
    return {..._jsonHeaders, 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const ApiException('Respuesta inesperada del backend');
  }

  String _errorMessageFromResponse(http.Response response, String fallback) {
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

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
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

class DemoSession {
  const DemoSession({
    required this.apiUrl,
    required this.environment,
    required this.user,
  });

  final String apiUrl;
  final String environment;
  final DemoUser user;
}

class DemoUser {
  const DemoUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.isActive,
  });

  factory DemoUser.fromJson(Map<String, dynamic> json) {
    return DemoUser(
      id: json['id'] as int,
      email: json['email'].toString(),
      fullName: json['full_name']?.toString() ?? 'Usuario',
      isActive: json['is_active'] == true,
    );
  }

  final int id;
  final String email;
  final String fullName;
  final bool isActive;
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
