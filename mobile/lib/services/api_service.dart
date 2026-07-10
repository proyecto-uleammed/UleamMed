import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../models/app_role.dart';
import '../models/caregiving_models.dart';
import '../models/local_models.dart';
import 'local_store.dart';

export '../models/local_models.dart';
export '../models/caregiving_models.dart';

abstract class UleamMedApi {
  Future<AppSession?> restoreSession();
  Future<AppSession> login({required String email, required String password});
  Future<AppSession> register({
    required String email,
    required String password,
    required String fullName,
    AppRole accountType = AppRole.patient,
  });
  Future<AppSession> loadAppSession();
  Future<AppSession> updateProfile({required String fullName});
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
  Future<MedicationMarkResult> recordScheduledDose({
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) {
    return recordMedicationStatus(medicationId, status);
  }

  Future<List<DoseConfirmation>> listDoseConfirmations();
  Future<List<Appointment>> listAppointments();
  Future<Appointment> saveAppointment(Appointment appointment);
  Future<void> deleteAppointment(String appointmentId);
  Future<List<EmergencyContact>> listEmergencyContacts();
  Future<EmergencyContact> saveEmergencyContact(EmergencyContact contact);
  Future<void> deleteEmergencyContact(String contactId);
  Future<List<HealthEntry>> listHealthEntries();
  Future<HealthEntry> saveHealthEntry(HealthEntry entry);
  Future<void> deleteHealthEntry(String entryId);
  Future<CaregiverInvitation> createCaregiverInvitation();
  Future<void> cancelCaregiverInvitation(int invitationId);
  Future<CaregiverLink> redeemCaregiverInvitation(String code);
  Future<List<CaregiverLink>> listCaregivingLinks();
  Future<CaregiverLink> approveCaregiverLink(int linkId);
  Future<CaregiverLink> rejectCaregiverLink(int linkId);
  Future<void> revokeCaregiverLink(int linkId);
  Future<List<CaregiverPatient>> listCaregiverPatients();
  Future<List<MedicationItem>> listCaregiverPatientMedications(int patientId);
  Future<MedicationItem> saveCaregiverPatientMedication(
    int patientId,
    MedicationItem medication,
  );
  Future<void> deleteCaregiverPatientMedication(
    int patientId,
    String medicationId,
  );
  Future<List<DoseConfirmation>> listCaregiverPatientDoseEvents(int patientId);
  Future<int> pendingSyncCount();
  Future<SyncSummary> synchronizePendingChanges();
}

class ApiService implements UleamMedApi {
  ApiService({
    http.Client? client,
    String? baseUrl,
    TokenStore? tokenStore,
    LocalStore? localStore,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _defaultBaseUrl,
       _tokenStore = tokenStore ?? SecureTokenStore(),
       _localStore = localStore ?? LocalStore();

  final http.Client _client;
  final String _baseUrl;
  final TokenStore _tokenStore;
  final LocalStore _localStore;
  String? _accessToken;
  String? _refreshToken;
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

  @override
  Future<AppSession?> restoreSession() async {
    final tokens = await _tokenStore.read();
    if (tokens == null) {
      return null;
    }

    _setTokensInMemory(tokens);
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

  @override
  Future<AppSession> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _loginUser(email: email, password: password);
    await _persistTokens(tokens);
    final session = await loadAppSession();
    return _finalizeSession(session);
  }

  @override
  Future<AppSession> register({
    required String email,
    required String password,
    required String fullName,
    AppRole accountType = AppRole.patient,
  }) async {
    if (accountType != AppRole.patient && accountType != AppRole.caregiver) {
      throw const ApiException('Tipo de cuenta no permitido');
    }
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/v1/auth/register'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'account_type': accountType.name,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException(
        _errorMessageFromResponse(response, 'No se pudo crear la cuenta'),
        response.statusCode,
      );
    }

    await _localStore.clearUserData();
    return login(email: email, password: password);
  }

  @override
  Future<AppSession> loadAppSession() async {
    final health = await _getJson(Uri.parse('$_baseUrl/health'));
    final user = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/users/me'),
      fallback: 'No se pudo cargar el perfil',
    );

    return AppSession(
      apiUrl: _baseUrl,
      environment: health['environment']?.toString() ?? 'development',
      user: AppUser.fromJson(user),
    );
  }

  @override
  Future<AppSession> updateProfile({required String fullName}) async {
    await _patchAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/users/me'),
      body: {'full_name': fullName.trim()},
      fallback: 'No se pudo actualizar el perfil',
    );

    return loadAppSession();
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
    final activeUserId = await _localStore.readActiveUserId();
    _accessToken = null;
    _refreshToken = null;
    await _tokenStore.clear();
    await _localStore.clearUserData();
    await _localStore.clearActiveUserId();
    if (activeUserId != null) {
      await _clearPhotoCache(activeUserId);
    }
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
      final merged = await _cacheMedicationPhotos(
        _mergeMedications(localItems, backendItems),
      );
      await _localStore.saveMedications(merged);
      return merged;
    } catch (_) {
      return localItems;
    }
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    return recordMedicationStatus(medicationId, DoseStatus.taken);
  }

  @override
  Future<MedicationItem> saveMedication(MedicationItem medication) async {
    MedicationItem? existing;
    for (final item in await _localStore.readMedications()) {
      if (item.id == medication.id) {
        existing = item;
        break;
      }
    }
    final localPending = await _localStore.upsertMedication(
      medication.copyWith(syncStatus: SyncStatus.pending),
    );
    final isBackendId = _isPersistedBackendId(medication.id);
    final uri = isBackendId
        ? Uri.parse('$_baseUrl/api/v1/medications/${medication.id}')
        : Uri.parse('$_baseUrl/api/v1/medications');
    final body = {
      'name': medication.name,
      'dose': medication.dose,
      'doseAmount': medication.doseAmount,
      'doseUnit': medication.doseUnit,
      'time': medication.time,
      'frequency': medication.frequency,
      'duration': medication.duration,
      'instructions': medication.instructions,
      'isImportant': medication.isImportant,
      'schedule': medication.effectiveSchedule.toJson(),
      if (isBackendId) 'taken': medication.taken,
    };
    late final Map<String, dynamic> data;
    try {
      data = isBackendId
          ? await _patchAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo actualizar el medicamento',
            )
          : await _postAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo crear el medicamento',
            );
    } catch (_) {
      return localPending;
    }

    var saved = MedicationItem.fromJson(
      data,
    ).copyWith(syncStatus: SyncStatus.synced, photoPath: medication.photoPath);
    if (!isBackendId) {
      await _localStore.deleteMedication(medication.id);
    }
    await _localStore.upsertMedication(saved);
    return _syncMedicationPhoto(saved, medication, existing);
  }

  Future<MedicationItem> _syncMedicationPhoto(
    MedicationItem saved,
    MedicationItem medication,
    MedicationItem? existing,
  ) async {
    final userId = await _localStore.readActiveUserId() ?? 'unknown';
    try {
      final removedPhoto =
          medication.photoPath.isEmpty &&
          (existing?.photoAvailable == true || saved.photoAvailable);
      if (removedPhoto) {
        await _deleteAuthorized(
          Uri.parse('$_baseUrl/api/v1/medications/${saved.id}/photo'),
          fallback: 'No se pudo eliminar la foto',
        );
        await _purgeMedicationPhotoCache(userId, saved.id);
        final cleared = saved.copyWith(photoAvailable: false, photoPath: '');
        await _localStore.upsertMedication(cleared);
        return cleared;
      }

      final shouldUpload =
          medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          _shouldUploadMedicationPhoto(
            localPhotoPath: medication.photoPath,
            hadPhotoAvailable: existing?.photoAvailable ?? saved.photoAvailable,
          );
      if (!shouldUpload) {
        await _localStore.upsertMedication(saved);
        return saved;
      }

      final photoData = await _uploadMedicationPhoto(
        saved.id,
        medication.photoPath,
      );
      final cachedFile = await _writeMedicationPhotoFile(
        scope: userId,
        medicationId: saved.id,
        bytes: await File(medication.photoPath).readAsBytes(),
      );
      saved = MedicationItem.fromJson(
        photoData,
      ).copyWith(syncStatus: SyncStatus.synced, photoPath: cachedFile.path);
      await _localStore.upsertMedication(saved);
      return saved;
    } catch (_) {
      final pending = saved.copyWith(
        syncStatus: SyncStatus.pending,
        photoPath: medication.photoPath,
      );
      await _localStore.upsertMedication(pending);
      return pending;
    }
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    await _localStore.deleteMedication(medicationId);
    await _localStore.deleteDoseConfirmationsForMedication(medicationId);
    final isBackendId = _isPersistedBackendId(medicationId);
    if (!isBackendId) {
      return;
    }
    try {
      await _deleteAuthorized(
        Uri.parse('$_baseUrl/api/v1/medications/$medicationId'),
        fallback: 'No se pudo eliminar el medicamento',
      );
    } catch (_) {
      // La eliminacion local se conserva para no bloquear el flujo offline.
    }
  }

  @override
  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  ) async {
    return recordScheduledDose(
      medicationId: medicationId,
      status: status,
      scheduledAt: DateTime.now(),
      sequenceNumber: 1,
    );
  }

  @override
  Future<MedicationMarkResult> recordScheduledDose({
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) async {
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
    final confirmation = DoseConfirmation(
      id: '${medication.id}-${scheduledAt.toUtc().millisecondsSinceEpoch}',
      medicationId: medication.id,
      medicationName: medication.name,
      status: status,
      recordedAt: DateTime.now(),
      scheduledAt: scheduledAt,
      sequenceNumber: sequenceNumber,
      snoozedUntil: snoozedUntil,
    );
    await _localStore.upsertDoseConfirmation(confirmation);

    final localResult = await _medicationResultFor(updated.id);
    if (!_isPersistedBackendId(medicationId)) {
      return localResult;
    }

    try {
      await _postAuthorizedJson(
        Uri.parse('$_baseUrl/api/v1/medications/$medicationId/dose-events'),
        body: {
          'client_event_id': confirmation.id,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'sequence_number': sequenceNumber,
          'status': status.name,
          'acted_at': confirmation.recordedAt.toUtc().toIso8601String(),
          'snoozed_until': snoozedUntil?.toUtc().toIso8601String(),
        },
        fallback: 'No se pudo sincronizar la toma',
      );
      await _localStore.upsertDoseConfirmation(
        confirmation.copyWith(syncStatus: SyncStatus.synced),
      );
      await _localStore.upsertMedication(
        updated.copyWith(syncStatus: SyncStatus.synced),
      );
      return _medicationResultFor(updated.id);
    } catch (_) {
      return localResult;
    }
  }

  @override
  Future<List<DoseConfirmation>> listDoseConfirmations() {
    return _localStore.readDoseConfirmations();
  }

  @override
  Future<List<Appointment>> listAppointments() {
    return _localStore.readAppointments();
  }

  @override
  Future<Appointment> saveAppointment(Appointment appointment) {
    return _localStore.upsertAppointment(appointment);
  }

  @override
  Future<void> deleteAppointment(String appointmentId) {
    return _localStore.deleteAppointment(appointmentId);
  }

  @override
  Future<List<EmergencyContact>> listEmergencyContacts() {
    return _localStore.readEmergencyContacts();
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
  Future<CaregiverInvitation> createCaregiverInvitation() async {
    final data = await _postAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/invitations'),
      fallback: 'No se pudo generar el codigo',
    );
    return CaregiverInvitation.fromJson(data);
  }

  @override
  Future<void> cancelCaregiverInvitation(int invitationId) {
    return _deleteAuthorized(
      Uri.parse('$_baseUrl/api/v1/caregiving/invitations/$invitationId'),
      fallback: 'No se pudo cancelar el codigo',
    );
  }

  @override
  Future<CaregiverLink> redeemCaregiverInvitation(String code) async {
    final data = await _postAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/invitations/redeem'),
      body: {'code': code.trim()},
      fallback: 'No se pudo enviar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<List<CaregiverLink>> listCaregivingLinks() async {
    final data = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/links'),
      fallback: 'No se pudieron cargar los vinculos',
    );
    return _decodeList(data, CaregiverLink.fromJson);
  }

  @override
  Future<CaregiverLink> approveCaregiverLink(int linkId) async {
    final data = await _postAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/links/$linkId/approve'),
      fallback: 'No se pudo aprobar al cuidador',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<CaregiverLink> rejectCaregiverLink(int linkId) async {
    final data = await _postAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/links/$linkId/reject'),
      fallback: 'No se pudo rechazar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<void> revokeCaregiverLink(int linkId) {
    return _deleteAuthorized(
      Uri.parse('$_baseUrl/api/v1/caregiving/links/$linkId'),
      fallback: 'No se pudo revocar el acceso',
    );
  }

  @override
  Future<List<CaregiverPatient>> listCaregiverPatients() async {
    final data = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/patients'),
      fallback: 'No se pudieron cargar los pacientes',
    );
    return _decodeList(data, CaregiverPatient.fromJson);
  }

  @override
  Future<List<MedicationItem>> listCaregiverPatientMedications(
    int patientId,
  ) async {
    final data = await _getAuthorizedJson(
      Uri.parse('$_baseUrl/api/v1/caregiving/patients/$patientId/medications'),
      fallback: 'No se pudieron cargar los medicamentos',
    );
    final items = _decodeList(data, MedicationItem.fromJson);
    return _cacheCaregiverPatientMedicationPhotos(patientId, items);
  }

  @override
  Future<MedicationItem> saveCaregiverPatientMedication(
    int patientId,
    MedicationItem medication,
  ) async {
    final isBackendId = _isPersistedBackendId(medication.id);
    MedicationItem? existing;
    if (isBackendId) {
      try {
        final data = await _getAuthorizedJson(
          Uri.parse(
            '$_baseUrl/api/v1/caregiving/patients/$patientId/medications',
          ),
          fallback: 'No se pudieron cargar los medicamentos',
        );
        for (final item in _decodeList(data, MedicationItem.fromJson)) {
          if (item.id == medication.id) {
            existing = item;
            break;
          }
        }
      } catch (_) {
        // Si falla la lectura previa, igual intentamos guardar.
      }
    }
    final uri = isBackendId
        ? Uri.parse(
            '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/${medication.id}',
          )
        : Uri.parse(
            '$_baseUrl/api/v1/caregiving/patients/$patientId/medications',
          );
    final body = {
      'name': medication.name,
      'dose': medication.dose,
      'doseAmount': medication.doseAmount,
      'doseUnit': medication.doseUnit,
      'time': medication.time,
      'frequency': medication.frequency,
      'duration': medication.duration,
      'instructions': medication.instructions,
      'isImportant': medication.isImportant,
      'schedule': medication.effectiveSchedule.toJson(),
      if (isBackendId) 'taken': medication.taken,
    };
    try {
      final data = isBackendId
          ? await _patchAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo actualizar el medicamento',
            )
          : await _postAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo crear el medicamento',
            );
      var saved = MedicationItem.fromJson(
        data,
      ).copyWith(syncStatus: SyncStatus.synced, photoPath: medication.photoPath);
      saved = await _syncCaregiverPatientMedicationPhoto(
        patientId: patientId,
        saved: saved,
        medication: medication,
        existing: existing,
      );
      return saved;
    } on ApiException catch (error) {
      if (error.statusCode == 405 || error.statusCode == 404) {
        throw ApiException(
          'El backend no tiene habilitado el CRUD de medicamentos para cuidadores. '
          'Despliega la rama Frontend-backend en ECS o usa el backend local en modo debug.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) async {
    if (!_isPersistedBackendId(medicationId)) {
      return;
    }
    await _deleteAuthorized(
      Uri.parse(
        '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/$medicationId',
      ),
      fallback: 'No se pudo eliminar el medicamento',
    );
  }

  Future<MedicationItem> _syncCaregiverPatientMedicationPhoto({
    required int patientId,
    required MedicationItem saved,
    required MedicationItem medication,
    MedicationItem? existing,
  }) async {
    final scope = 'caregiver/$patientId';
    try {
      final removedPhoto =
          medication.photoPath.isEmpty &&
          (existing?.photoAvailable == true || saved.photoAvailable);
      if (removedPhoto) {
        await _deleteCaregiverPatientMedicationPhoto(patientId, saved.id);
        await _purgeMedicationPhotoCache(scope, saved.id);
        return saved.copyWith(photoAvailable: false, photoPath: '');
      }

      final shouldUpload =
          medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          _shouldUploadMedicationPhoto(
            localPhotoPath: medication.photoPath,
            hadPhotoAvailable: existing?.photoAvailable ?? saved.photoAvailable,
          );
      if (!shouldUpload) {
        return saved;
      }

      final photoData = await _uploadCaregiverPatientMedicationPhoto(
        patientId,
        saved.id,
        medication.photoPath,
      );
      final cachedFile = await _writeMedicationPhotoFile(
        scope: scope,
        medicationId: saved.id,
        bytes: await File(medication.photoPath).readAsBytes(),
      );
      return MedicationItem.fromJson(photoData).copyWith(
        syncStatus: SyncStatus.synced,
        photoPath: cachedFile.path,
        photoAvailable: true,
      );
    } catch (_) {
      return saved;
    }
  }

  Future<void> _deleteCaregiverPatientMedicationPhoto(
    int patientId,
    String medicationId,
  ) async {
    await _deleteAuthorized(
      Uri.parse(
        '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/$medicationId/photo',
      ),
      fallback: 'No se pudo eliminar la foto',
    );
  }

  @override
  Future<List<DoseConfirmation>> listCaregiverPatientDoseEvents(
    int patientId,
  ) async {
    final data = await _getAuthorizedList(
      Uri.parse(
        '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/dose-events',
      ),
      fallback: 'No se pudo cargar el historial del paciente',
    );
    return data
        .whereType<Map>()
        .map(
          (json) => DoseConfirmation.fromBackendEvent(
            Map<String, dynamic>.from(json),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> _uploadCaregiverPatientMedicationPhoto(
    int patientId,
    String medicationId,
    String path,
  ) async {
    Future<http.StreamedResponse> send(String token) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/$medicationId/photo',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          path,
          contentType: _photoContentType(path),
        ),
      );
      return _client.send(request);
    }

    var response = await send(await _ensureAccessToken());
    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await send(await _ensureAccessToken());
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('No se pudo subir la foto', response.statusCode);
    }
    final decoded = jsonDecode(body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  @override
  Future<int> pendingSyncCount() {
    return _localStore.pendingSyncCount();
  }

  @override
  Future<SyncSummary> synchronizePendingChanges() async {
    var processed = 0;
    final medications = await _localStore.readMedications();
    for (final medication in medications.where(
      (item) => item.syncStatus == SyncStatus.pending,
    )) {
      final saved = await saveMedication(medication);
      if (saved.syncStatus == SyncStatus.synced) {
        processed++;
      }
    }
    final confirmations = await _localStore.readDoseConfirmations();
    for (final confirmation in confirmations.where(
      (item) => item.syncStatus == SyncStatus.pending,
    )) {
      if (int.tryParse(confirmation.medicationId) == null ||
          confirmation.scheduledAt == null) {
        continue;
      }
      try {
        await _postAuthorizedJson(
          Uri.parse(
            '$_baseUrl/api/v1/medications/'
            '${confirmation.medicationId}/dose-events',
          ),
          body: {
            'client_event_id': confirmation.id,
            'scheduled_at': confirmation.scheduledAt!.toUtc().toIso8601String(),
            'sequence_number': confirmation.sequenceNumber,
            'status': confirmation.status.name,
            'acted_at': confirmation.recordedAt.toUtc().toIso8601String(),
            'snoozed_until': confirmation.snoozedUntil
                ?.toUtc()
                .toIso8601String(),
          },
          fallback: 'No se pudo sincronizar la toma',
        );
        await _localStore.upsertDoseConfirmation(
          confirmation.copyWith(syncStatus: SyncStatus.synced),
        );
        processed++;
      } catch (_) {
        // Conserva el evento pendiente para el siguiente intento.
      }
    }
    final pending = await _localStore.pendingSyncCount();
    return SyncSummary(
      processed: processed,
      pending: pending,
      message: pending == 0
          ? 'Todo está sincronizado.'
          : 'Quedan $pending cambios por sincronizar.',
    );
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
        .map(
          (json) => MedicationItem.fromJson(
            Map<String, dynamic>.from(json),
          ).copyWith(syncStatus: SyncStatus.synced),
        )
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
        if (int.tryParse(local.id) != null) {
          byId[local.id] = local;
        }
        continue;
      }

      final backend = byId[local.id];
      if (backend != null) {
        byId[local.id] = backend.copyWith(
          taken: backend.taken,
          photoPath: '',
        );
      }
    }
    return byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<List<MedicationItem>> _cacheMedicationPhotos(
    List<MedicationItem> medications,
  ) async {
    final scope = await _localStore.readActiveUserId() ?? 'unknown';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (!medication.photoAvailable) {
        await _purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _getAuthorizedBytes(
          Uri.parse('$_baseUrl/api/v1/medications/${medication.id}/photo'),
        );
        final file = await _writeMedicationPhotoFile(
          scope: scope,
          medicationId: medication.id,
          bytes: bytes,
        );
        result.add(medication.copyWith(photoPath: file.path));
      } catch (_) {
        result.add(medication.copyWith(photoPath: ''));
      }
    }
    return result;
  }

  Future<List<MedicationItem>> _cacheCaregiverPatientMedicationPhotos(
    int patientId,
    List<MedicationItem> medications,
  ) async {
    final scope = 'caregiver/$patientId';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (!medication.photoAvailable) {
        await _purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _getAuthorizedBytes(
          Uri.parse(
            '$_baseUrl/api/v1/caregiving/patients/$patientId/medications/${medication.id}/photo',
          ),
        );
        final file = await _writeMedicationPhotoFile(
          scope: scope,
          medicationId: medication.id,
          bytes: bytes,
        );
        result.add(medication.copyWith(photoPath: file.path));
      } catch (_) {
        result.add(medication.copyWith(photoPath: ''));
      }
    }
    return result;
  }

  bool _shouldUploadMedicationPhoto({
    required String localPhotoPath,
    required bool hadPhotoAvailable,
  }) {
    if (!_isManagedMedicationPhotoPath(localPhotoPath)) {
      return true;
    }
    return !hadPhotoAvailable;
  }

  bool _isManagedMedicationPhotoPath(String path) {
    return path.replaceAll('\\', '/').contains('/medication_photos/');
  }

  Future<void> _purgeMedicationPhotoCache(
    String scope,
    String medicationId,
  ) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/medication_photos/$scope');
      if (!await directory.exists()) {
        return;
      }
      for (final entity in directory.listSync()) {
        if (entity is! File) {
          continue;
        }
        final name = entity.uri.pathSegments.last;
        if (name.startsWith('$medicationId-') ||
            name.startsWith('$medicationId.')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // En tests unitarios o sin acceso al filesystem, omitir la purga local.
    }
  }

  Future<File> _writeMedicationPhotoFile({
    required String scope,
    required String medicationId,
    required List<int> bytes,
  }) async {
    await _purgeMedicationPhotoCache(scope, medicationId);
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/medication_photos/$scope');
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/$medicationId-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _clearPhotoCache(String userId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/medication_photos/$userId');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<Map<String, dynamic>> _uploadMedicationPhoto(
    String medicationId,
    String path,
  ) async {
    Future<http.StreamedResponse> send(String token) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/v1/medications/$medicationId/photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          path,
          contentType: _photoContentType(path),
        ),
      );
      return _client.send(request);
    }

    var response = await send(await _ensureAccessToken());
    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await send(await _ensureAccessToken());
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('No se pudo subir la foto', response.statusCode);
    }
    final decoded = jsonDecode(body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  MediaType _photoContentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Future<List<int>> _getAuthorizedBytes(Uri uri) async {
    var response = await _client.get(
      uri,
      headers: _authorizedHeaders(await _ensureAccessToken()),
    );
    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await _client.get(
        uri,
        headers: _authorizedHeaders(await _ensureAccessToken()),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('No se pudo descargar la foto', response.statusCode);
    }
    return response.bodyBytes;
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

  Future<List<dynamic>> _getAuthorizedList(
    Uri uri, {
    required String fallback,
  }) async {
    final token = await _ensureAccessToken();
    var response = await _client.get(uri, headers: _authorizedHeaders(token));

    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await _client.get(
        uri,
        headers: _authorizedHeaders(await _ensureAccessToken()),
      );
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

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const ApiException('Respuesta inesperada del historial');
    }
    return decoded;
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

  Future<void> _deleteAuthorized(Uri uri, {required String fallback}) async {
    final token = await _ensureAccessToken();
    var response = await _client.delete(
      uri,
      headers: _authorizedHeaders(token),
    );

    if (response.statusCode == 401 && await _refreshAccessToken()) {
      response = await _client.delete(
        uri,
        headers: _authorizedHeaders(await _ensureAccessToken()),
      );
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
  }

  List<T> _decodeList<T>(
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

bool _isPersistedBackendId(String id) {
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
