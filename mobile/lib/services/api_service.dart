import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';
import '../models/app_role.dart';
import '../models/caregiving_models.dart';
import '../models/local_models.dart';
import 'auth_api.dart';
import 'health_api.dart';
import 'local_store.dart';
import 'medication_api.dart';
import 'sync_api.dart';

export '../core/http_client.dart';
export '../models/local_models.dart';
export '../models/caregiving_models.dart';
export 'auth_api.dart';

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
  Future<List<MedicationItem>> listDeletedMedications();
  Future<MedicationItem> restoreMedication(String medicationId);
  Future<MedicationItem?> resolveMedicationSyncConflict(
    int conflictId,
    String resolution,
  );
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
  Future<void> recordCaregiverPatientDoseEvent({
    required int patientId,
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  });
  Future<List<MedicationItem>> listCaregiverPatientDeletedMedications(
    int patientId,
  );
  Future<MedicationItem> restoreCaregiverPatientMedication(
    int patientId,
    String medicationId,
  );
  Future<List<DoseConfirmation>> listCaregiverPatientDoseEvents(int patientId);
  Future<List<Appointment>> listCaregiverPatientAppointments(int patientId);
  Future<Appointment> saveCaregiverPatientAppointment(
    int patientId,
    Appointment appointment,
  );
  Future<void> deleteCaregiverPatientAppointment(
    int patientId,
    String appointmentId,
  );
  Future<List<HealthEntry>> listCaregiverPatientHealthEntries(int patientId);
  Future<HealthEntry> saveCaregiverPatientHealthEntry(
    int patientId,
    HealthEntry entry,
  );
  Future<void> deleteCaregiverPatientHealthEntry(
    int patientId,
    String entryId,
  );
  Future<MedicalProfile> loadCaregiverPatientMedicalProfile(int patientId);
  Future<List<EmergencyContact>> listCaregiverPatientEmergencyContacts(
    int patientId,
  );
  Future<int> clearDoseHistory({DateTime? before});
  Future<int> clearCaregiverPatientDoseHistory(
    int patientId, {
    DateTime? before,
  });
  Future<int> pendingSyncCount();
  Future<SyncSummary> synchronizePendingChanges();

  /// Libera recursos propios (por ejemplo el `http.Client`).
  /// Implementacion opcional: los dobles de prueba no necesitan sobreescribirlo.
  void dispose() {}
}

class ApiService implements UleamMedApi {
  ApiService({
    http.Client? client,
    String? baseUrl,
    TokenStore? tokenStore,
    LocalStore? localStore,
  }) : _httpClient = ApiHttpClient(
         client: client,
         baseUrl: baseUrl,
         tokenStore: tokenStore,
       ),
       _localStore = localStore ?? LocalStore() {
    _authApi = AuthApi(
      httpClient: _httpClient,
      localStore: _localStore,
      clearPhotoCache: _clearPhotoCache,
    );
    _syncApi = SyncApi(
      httpClient: _httpClient,
      localStore: _localStore,
      applySyncResults: _applySyncResults,
    );
    _healthApi = HealthApi(httpClient: _httpClient, localStore: _localStore);
    _medicationApi = MedicationApi(
      httpClient: _httpClient,
      localStore: _localStore,
      synchronizePendingChanges: _syncApi.synchronizePendingChanges,
    );
  }

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  late final AuthApi _authApi;
  late final SyncApi _syncApi;
  late final HealthApi _healthApi;
  late final MedicationApi _medicationApi;

  @override
  Future<AppSession?> restoreSession() => _authApi.restoreSession();

  @override
  Future<AppSession> login({
    required String email,
    required String password,
  }) => _authApi.login(email: email, password: password);

  @override
  Future<AppSession> register({
    required String email,
    required String password,
    required String fullName,
    AppRole accountType = AppRole.patient,
  }) => _authApi.register(
    email: email,
    password: password,
    fullName: fullName,
    accountType: accountType,
  );

  @override
  Future<AppSession> loadAppSession() => _authApi.loadAppSession();

  @override
  Future<AppSession> updateProfile({required String fullName}) =>
      _authApi.updateProfile(fullName: fullName);

  @override
  Future<String> requestPasswordReset({required String email}) =>
      _authApi.requestPasswordReset(email: email);

  @override
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _authApi.resetPassword(
    email: email,
    code: code,
    newPassword: newPassword,
  );

  @override
  void dispose() {
    _httpClient.close();
  }

  @override
  Future<void> logout() => _authApi.logout();

  @override
  Future<MedicalProfile> loadMedicalProfile() async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/medical-profile'),
        fallback: 'No se pudo cargar el perfil medico',
      );
      final remote = MedicalProfile.fromBackendJson(data);
      await _localStore.saveMedicalProfile(remote);
      return remote;
    } catch (_) {
      return _localStore.readMedicalProfile();
    }
  }

  @override
  Future<MedicalProfile> saveMedicalProfile(MedicalProfile profile) async {
    final localPending = profile.copyWith(syncStatus: SyncStatus.pending);
    await _localStore.saveMedicalProfile(localPending);
    try {
      final data = await _httpClient.putAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/medical-profile'),
        body: _medicalProfilePayload(profile),
        fallback: 'No se pudo guardar el perfil medico',
      );
      final saved = MedicalProfile.fromBackendJson(data);
      await _localStore.saveMedicalProfile(saved);
      return saved;
    } catch (_) {
      return localPending;
    }
  }

  @override
  Future<List<MedicationItem>> listMedications() =>
      _medicationApi.listMedications();

  @override
  Future<List<MedicationItem>> listDeletedMedications() =>
      _medicationApi.listDeletedMedications();

  @override
  Future<MedicationItem> restoreMedication(String medicationId) =>
      _medicationApi.restoreMedication(medicationId);

  @override
  Future<MedicationItem?> resolveMedicationSyncConflict(
    int conflictId,
    String resolution,
  ) => _medicationApi.resolveMedicationSyncConflict(conflictId, resolution);

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) =>
      _medicationApi.markMedicationTaken(medicationId);

  @override
  Future<MedicationItem> saveMedication(MedicationItem medication) =>
      _medicationApi.saveMedication(medication);

  Future<MedicationItem?> _findLocalCaregiverMedication(
    int patientId, {
    required String id,
    String? clientMedicationId,
  }) async {
    for (final item in await _localStore.readCaregiverPatientMedications(
      patientId,
    )) {
      if (item.id == id ||
          (clientMedicationId != null &&
              item.clientMedicationId == clientMedicationId)) {
        return item;
      }
    }
    return null;
  }

  @override
  Future<void> deleteMedication(String medicationId) =>
      _medicationApi.deleteMedication(medicationId);

  @override
  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  ) => _medicationApi.recordMedicationStatus(medicationId, status);

  @override
  Future<MedicationMarkResult> recordScheduledDose({
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) => _medicationApi.recordScheduledDose(
    medicationId: medicationId,
    status: status,
    scheduledAt: scheduledAt,
    sequenceNumber: sequenceNumber,
    snoozedUntil: snoozedUntil,
  );

  @override
  Future<List<DoseConfirmation>> listDoseConfirmations() =>
      _medicationApi.listDoseConfirmations();

  @override
  Future<List<Appointment>> listAppointments() => _healthApi.listAppointments();

  @override
  Future<Appointment> saveAppointment(Appointment appointment) =>
      _healthApi.saveAppointment(appointment);

  @override
  Future<void> deleteAppointment(String appointmentId) =>
      _healthApi.deleteAppointment(appointmentId);

  @override
  Future<List<EmergencyContact>> listEmergencyContacts() =>
      _healthApi.listEmergencyContacts();

  @override
  Future<EmergencyContact> saveEmergencyContact(EmergencyContact contact) =>
      _healthApi.saveEmergencyContact(contact);

  @override
  Future<void> deleteEmergencyContact(String contactId) =>
      _healthApi.deleteEmergencyContact(contactId);

  @override
  Future<List<HealthEntry>> listHealthEntries() =>
      _healthApi.listHealthEntries();

  @override
  Future<HealthEntry> saveHealthEntry(HealthEntry entry) =>
      _healthApi.saveHealthEntry(entry);

  @override
  Future<void> deleteHealthEntry(String entryId) =>
      _healthApi.deleteHealthEntry(entryId);

  @override
  Future<CaregiverInvitation> createCaregiverInvitation() async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/invitations'),
      fallback: 'No se pudo generar el codigo',
    );
    return CaregiverInvitation.fromJson(data);
  }

  @override
  Future<void> cancelCaregiverInvitation(int invitationId) {
    return _httpClient.deleteAuthorized(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/invitations/$invitationId'),
      fallback: 'No se pudo cancelar el codigo',
    );
  }

  @override
  Future<CaregiverLink> redeemCaregiverInvitation(String code) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/invitations/redeem'),
      body: {'code': code.trim()},
      fallback: 'No se pudo enviar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<List<CaregiverLink>> listCaregivingLinks() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links'),
      fallback: 'No se pudieron cargar los vinculos',
    );
    return _httpClient.decodeList(data, CaregiverLink.fromJson);
  }

  @override
  Future<CaregiverLink> approveCaregiverLink(int linkId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId/approve'),
      fallback: 'No se pudo aprobar al cuidador',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<CaregiverLink> rejectCaregiverLink(int linkId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId/reject'),
      fallback: 'No se pudo rechazar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  @override
  Future<void> revokeCaregiverLink(int linkId) {
    return _httpClient.deleteAuthorized(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId'),
      fallback: 'No se pudo revocar el acceso',
    );
  }

  @override
  Future<List<CaregiverPatient>> listCaregiverPatients() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/patients'),
      fallback: 'No se pudieron cargar los pacientes',
    );
    return _httpClient.decodeList(data, CaregiverPatient.fromJson);
  }

  @override
  Future<List<MedicationItem>> listCaregiverPatientMedications(
    int patientId,
  ) async {
    final localItems = await _localStore.readCaregiverPatientMedications(
      patientId,
    );
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse(
          '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications',
        ),
        fallback: 'No se pudieron cargar los medicamentos',
      );
      final backendItems = await _cacheCaregiverPatientMedicationPhotos(
        patientId,
        _httpClient.decodeList(data, MedicationItem.fromJson),
      );
      final merged = _medicationApi.mergeMedications(localItems, backendItems);
      await _localStore.saveCaregiverPatientMedications(patientId, merged);
      return merged;
    } catch (_) {
      return localItems;
    }
  }

  @override
  Future<MedicationItem> saveCaregiverPatientMedication(
    int patientId,
    MedicationItem medication,
  ) async {
    final clientMedicationId = medication.clientMedicationId ?? medication.id;
    final existing = await _findLocalCaregiverMedication(
      patientId,
      id: medication.id,
      clientMedicationId: clientMedicationId,
    );
    final localPending = await _localStore.upsertCaregiverPatientMedication(
      patientId,
      medication.copyWith(
        syncStatus: SyncStatus.pending,
        clientMedicationId: clientMedicationId,
      ),
    );
    await _localStore.upsertSyncAction(
      _medicationApi.syncActionForMedication(
        operationType: isPersistedBackendId(medication.id)
            ? SyncActionType.updateMedication
            : SyncActionType.createMedication,
        medication: localPending,
        patientId: patientId,
        actorRole: 'caregiver',
      ),
    );
    try {
      await synchronizePendingChanges();
    } catch (_) {
      // Conserva el cambio local del cuidador hasta recuperar conexion.
    }
    var result =
        await _findLocalCaregiverMedication(
          patientId,
          id: localPending.id,
          clientMedicationId: clientMedicationId,
        ) ??
        localPending;
    if (isPersistedBackendId(result.id)) {
      result = await _syncCaregiverPatientMedicationPhoto(
        patientId: patientId,
        saved: result,
        medication: localPending,
        existing: existing,
      );
      await _localStore.upsertCaregiverPatientMedication(patientId, result);
    }
    return result;
  }

  @override
  Future<void> deleteCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) async {
    final existing = await _findLocalCaregiverMedication(
      patientId,
      id: medicationId,
    );
    await _localStore.deleteCaregiverPatientMedication(patientId, medicationId);
    if (existing == null) {
      return;
    }
    await _localStore.upsertSyncAction(
      _medicationApi.syncActionForMedication(
        operationType: SyncActionType.deleteMedication,
        medication: existing,
        patientId: patientId,
        actorRole: 'caregiver',
      ),
    );
    unawaited(synchronizePendingChanges());
  }

  @override
  Future<void> recordCaregiverPatientDoseEvent({
    required int patientId,
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) async {
    final recordedAt = DateTime.now();
    final medication = await _findLocalCaregiverMedication(
      patientId,
      id: medicationId,
    );
    final confirmation = DoseConfirmation(
      id: 'caregiver-$patientId-$medicationId-${scheduledAt.toUtc().millisecondsSinceEpoch}',
      medicationId: medicationId,
      medicationName: medication?.name ?? 'Medicamento',
      status: status,
      recordedAt: recordedAt,
      scheduledAt: scheduledAt,
      sequenceNumber: sequenceNumber,
      snoozedUntil: snoozedUntil,
    );
    await _localStore.upsertDoseConfirmation(confirmation);
    await _localStore.upsertSyncAction(
      PendingSyncAction(
        clientOperationId: confirmation.id,
        operationType: SyncActionType.doseEvent,
        createdAt: recordedAt,
        payload: {
          'client_event_id':
              'caregiver-$medicationId-${scheduledAt.toUtc().millisecondsSinceEpoch}',
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'sequence_number': sequenceNumber,
          'status': status.name,
          'acted_at': recordedAt.toUtc().toIso8601String(),
          'snoozed_until': snoozedUntil?.toUtc().toIso8601String(),
        },
        clientMedicationId: medication?.clientMedicationId ?? medicationId,
        serverMedicationId: isPersistedBackendId(medicationId)
            ? medicationId
            : null,
        patientId: patientId,
        actorRole: 'caregiver',
      ),
    );
    unawaited(synchronizePendingChanges());
  }

  @override
  Future<List<MedicationItem>> listCaregiverPatientDeletedMedications(
    int patientId,
  ) async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse(
          '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/trash',
        ),
        fallback: 'No se pudo cargar la papelera',
      );
      return _httpClient.decodeList(data, MedicationItem.fromJson);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<MedicationItem> restoreCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/$medicationId/restore',
      ),
      fallback: 'No se pudo restaurar el medicamento',
    );
    return MedicationItem.fromJson(
      data,
    ).copyWith(syncStatus: SyncStatus.synced);
  }

  @override
  Future<List<Appointment>> listCaregiverPatientAppointments(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/appointments'),
      fallback: 'No se pudieron cargar las consultas',
    );
    return _httpClient.decodeList(data, Appointment.fromBackendJson);
  }

  @override
  Future<Appointment> saveCaregiverPatientAppointment(
    int patientId,
    Appointment appointment,
  ) async {
    final isBackendId = isPersistedBackendId(appointment.id);
    final uri = isBackendId
        ? Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/appointments/${appointment.id}',
          )
        : Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/appointments',
          );
    final body = _healthApi.appointmentPayload(appointment);
    try {
      final data = isBackendId
          ? await _httpClient.patchAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo actualizar la consulta',
            )
          : await _httpClient.postAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo crear la consulta',
            );
      return Appointment.fromBackendJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 405 || error.statusCode == 404) {
        throw ApiException(
          'El backend no tiene habilitadas las consultas para cuidadores. '
          'Despliega la rama Frontend-backend en ECS o usa el backend local en modo debug.',
          error.statusCode,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteCaregiverPatientAppointment(
    int patientId,
    String appointmentId,
  ) async {
    if (!isPersistedBackendId(appointmentId)) {
      return;
    }
    await _httpClient.deleteAuthorized(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/appointments/$appointmentId',
      ),
      fallback: 'No se pudo eliminar la consulta',
    );
  }

  @override
  Future<List<HealthEntry>> listCaregiverPatientHealthEntries(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/health-entries',
      ),
      fallback: 'No se pudieron cargar las condiciones',
    );
    return _httpClient.decodeList(data, HealthEntry.fromBackendJson);
  }

  @override
  Future<HealthEntry> saveCaregiverPatientHealthEntry(
    int patientId,
    HealthEntry entry,
  ) async {
    final isBackendId = isPersistedBackendId(entry.id);
    final uri = isBackendId
        ? Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/health-entries/${entry.id}',
          )
        : Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/health-entries',
          );
    final body = _healthApi.healthEntryPayload(entry);
    final data = isBackendId
        ? await _httpClient.patchAuthorizedJson(
            uri,
            body: body,
            fallback: 'No se pudo actualizar el registro',
          )
        : await _httpClient.postAuthorizedJson(
            uri,
            body: body,
            fallback: 'No se pudo crear el registro',
          );
    return HealthEntry.fromBackendJson(data);
  }

  @override
  Future<void> deleteCaregiverPatientHealthEntry(
    int patientId,
    String entryId,
  ) async {
    if (!isPersistedBackendId(entryId)) {
      return;
    }
    await _httpClient.deleteAuthorized(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/health-entries/$entryId',
      ),
      fallback: 'No se pudo eliminar el registro',
    );
  }

  @override
  Future<MedicalProfile> loadCaregiverPatientMedicalProfile(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medical-profile',
      ),
      fallback: 'No se pudo cargar el perfil medico',
    );
    return MedicalProfile.fromBackendJson(data);
  }

  @override
  Future<List<EmergencyContact>> listCaregiverPatientEmergencyContacts(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/emergency-contacts',
      ),
      fallback: 'No se pudieron cargar los contactos',
    );
    return _httpClient.decodeList(data, EmergencyContact.fromBackendJson);
  }

  @override
  Future<int> clearDoseHistory({DateTime? before}) =>
      _medicationApi.clearDoseHistory(before: before);

  @override
  Future<int> clearCaregiverPatientDoseHistory(
    int patientId, {
    DateTime? before,
  }) async {
    final uri = before == null
        ? Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/dose-events',
          )
        : Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/dose-events?before=${Uri.encodeComponent(before.toUtc().toIso8601String())}',
          );
    final data = await _deleteAuthorizedJson(
      uri,
      fallback: 'No se pudo limpiar el historial',
    );
    return data['deleted'] as int? ?? 0;
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
        await _medicationApi.purgeMedicationPhotoCache(scope, saved.id);
        final cleared = saved.copyWith(photoAvailable: false, photoPath: '');
        await _localStore.upsertCaregiverPatientMedication(patientId, cleared);
        return cleared;
      }

      final shouldUpload =
          medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          _medicationApi.shouldUploadMedicationPhoto(
            localPhotoPath: medication.photoPath,
            hadPhotoAvailable: existing?.photoAvailable ?? saved.photoAvailable,
          );
      if (!shouldUpload) {
        await _localStore.upsertCaregiverPatientMedication(patientId, saved);
        return saved;
      }

      final photoData = await _uploadCaregiverPatientMedicationPhoto(
        patientId,
        saved.id,
        medication.photoPath,
      );
      final cachedFile = await _medicationApi.writeMedicationPhotoFile(
        scope: scope,
        medicationId: saved.id,
        bytes: await File(medication.photoPath).readAsBytes(),
      );
      final synced = MedicationItem.fromJson(photoData).copyWith(
        syncStatus: SyncStatus.synced,
        photoPath: cachedFile.path,
        photoAvailable: true,
      );
      await _localStore.upsertCaregiverPatientMedication(patientId, synced);
      return synced;
    } catch (_) {
      final pending = saved.copyWith(
        syncStatus: SyncStatus.pending,
        photoPath: medication.photoPath,
      );
      await _localStore.upsertCaregiverPatientMedication(patientId, pending);
      return pending;
    }
  }

  Future<void> _deleteCaregiverPatientMedicationPhoto(
    int patientId,
    String medicationId,
  ) async {
    await _httpClient.deleteAuthorized(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/$medicationId/photo',
      ),
      fallback: 'No se pudo eliminar la foto',
    );
  }

  @override
  Future<List<DoseConfirmation>> listCaregiverPatientDoseEvents(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedList(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/dose-events',
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
          '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/$medicationId/photo',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          path,
          contentType: _medicationApi.photoContentType(path),
        ),
      );
      return _httpClient.client.send(request);
    }

    final token = await _httpClient.ensureAccessToken();
    var response = await send(token);
    if (response.statusCode == 401 &&
        await _httpClient.refreshAccessToken(staleToken: token)) {
      response = await send(await _httpClient.ensureAccessToken());
    }
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('No se pudo subir la foto', response.statusCode);
    }
    final decoded = jsonDecode(body);
    return Map<String, dynamic>.from(decoded as Map);
  }

  @override
  Future<int> pendingSyncCount() => _syncApi.pendingSyncCount();

  @override
  Future<SyncSummary> synchronizePendingChanges() =>
      _syncApi.synchronizePendingChanges();

  Future<int> _applySyncResults(
    Map<String, dynamic> data,
    List<PendingSyncAction> actions, {
    int? caregiverPatientId,
  }) async {
    var processed = 0;
    final byOperation = {
      for (final action in actions) action.clientOperationId: action,
    };
    final results = data['results'];
    if (results is! List) {
      return 0;
    }
    for (final raw in results.whereType<Map>()) {
      final result = Map<String, dynamic>.from(raw);
      final operationId = result['client_operation_id']?.toString() ?? '';
      final action = byOperation[operationId];
      if (action == null) {
        continue;
      }
      final status = result['status']?.toString() ?? '';
      if (status == 'synced' || status == 'skipped') {
        await _localStore.removeSyncAction(action.clientOperationId);
        await _applySyncedMedicationResult(
          result['medication'],
          action,
          caregiverPatientId: caregiverPatientId,
        );
        if (action.operationType == SyncActionType.doseEvent) {
          await _localStore.upsertDoseConfirmationByIdAsSynced(
            action.clientOperationId,
          );
        }
        processed++;
      } else if (status == 'conflict') {
        await _localStore.removeSyncAction(action.clientOperationId);
        await _markMedicationConflict(
          action,
          result['conflict'],
          caregiverPatientId: caregiverPatientId,
        );
        processed++;
      } else {
        await _localStore.upsertSyncAction(
          action.copyWith(
            syncStatus: SyncStatus.pending,
            retryCount: action.retryCount + 1,
            lastError:
                result['message']?.toString() ?? 'No se pudo sincronizar',
          ),
        );
      }
    }
    return processed;
  }

  Future<void> _applySyncedMedicationResult(
    Object? rawMedication,
    PendingSyncAction action, {
    int? caregiverPatientId,
  }) async {
    if (rawMedication is! Map) {
      if (action.operationType == SyncActionType.deleteMedication) {
        return;
      }
      return;
    }
    final saved = MedicationItem.fromJson(
      Map<String, dynamic>.from(rawMedication),
    ).copyWith(syncStatus: SyncStatus.synced);

    final current = caregiverPatientId == null
        ? await _medicationApi.findLocalMedication(
            id: saved.id,
            clientMedicationId: action.clientMedicationId,
          )
        : await _findLocalCaregiverMedication(
            caregiverPatientId,
            id: saved.id,
            clientMedicationId: action.clientMedicationId,
          );
    final withLocalPhoto = saved.copyWith(photoPath: current?.photoPath ?? '');
    final existingBeforeSync = current;

    if (caregiverPatientId == null) {
      if (current != null && current.id != saved.id) {
        await _localStore.deleteMedication(current.id);
      }
      await _localStore.upsertMedication(withLocalPhoto);
      if (isPersistedBackendId(withLocalPhoto.id) &&
          (withLocalPhoto.photoPath.isNotEmpty ||
              existingBeforeSync?.photoAvailable == true)) {
        await _medicationApi.syncMedicationPhoto(
          withLocalPhoto,
          withLocalPhoto,
          existingBeforeSync,
        );
      }
    } else {
      if (current != null && current.id != saved.id) {
        await _localStore.deleteCaregiverPatientMedication(
          caregiverPatientId,
          current.id,
        );
      }
      await _localStore.upsertCaregiverPatientMedication(
        caregiverPatientId,
        withLocalPhoto,
      );
      if (isPersistedBackendId(withLocalPhoto.id) &&
          (withLocalPhoto.photoPath.isNotEmpty ||
              existingBeforeSync?.photoAvailable == true)) {
        final synced = await _syncCaregiverPatientMedicationPhoto(
          patientId: caregiverPatientId,
          saved: withLocalPhoto,
          medication: withLocalPhoto,
          existing: existingBeforeSync,
        );
        await _localStore.upsertCaregiverPatientMedication(
          caregiverPatientId,
          synced,
        );
      }
    }
  }

  Future<void> _markMedicationConflict(
    PendingSyncAction action,
    Object? rawConflict, {
    int? caregiverPatientId,
  }) async {
    final conflict = rawConflict is Map
        ? Map<String, dynamic>.from(rawConflict)
        : const <String, dynamic>{};
    final conflictId = int.tryParse(conflict['id']?.toString() ?? '');
    final message = 'Posible duplicado: revisa antes de sincronizar.';
    if (caregiverPatientId == null) {
      final current = await _medicationApi.findLocalMedication(
        id: action.clientMedicationId ?? '',
        clientMedicationId: action.clientMedicationId,
      );
      if (current != null) {
        await _localStore.upsertMedication(
          current.copyWith(
            syncStatus: SyncStatus.conflict,
            syncConflictId: conflictId,
            lastSyncError: message,
          ),
        );
      }
      return;
    }
    final current = await _findLocalCaregiverMedication(
      caregiverPatientId,
      id: action.clientMedicationId ?? '',
      clientMedicationId: action.clientMedicationId,
    );
    if (current != null) {
      await _localStore.upsertCaregiverPatientMedication(
        caregiverPatientId,
        current.copyWith(
          syncStatus: SyncStatus.conflict,
          syncConflictId: conflictId,
          lastSyncError: message,
        ),
      );
    }
  }

  Map<String, dynamic> _medicalProfilePayload(MedicalProfile profile) {
    return {
      'birthDate': profile.birthDate,
      'bloodType': profile.bloodType,
      'conditions': profile.conditions,
      'allergies': profile.allergies,
      'importantNotes': profile.importantNotes,
      'emergencyContactName': profile.emergencyContactName,
      'emergencyContactPhone': profile.emergencyContactPhone,
      'shareWithCaregivers': profile.shareWithCaregivers,
    };
  }

  Future<Map<String, dynamic>> _deleteAuthorizedJson(
    Uri uri, {
    required String fallback,
  }) {
    return _httpClient.authorizedJson(
      request: (token) => _httpClient.client.delete(
        uri,
        headers: _httpClient.authorizedHeaders(token),
      ),
      fallback: fallback,
    );
  }

  Future<List<MedicationItem>> _cacheCaregiverPatientMedicationPhotos(
    int patientId,
    List<MedicationItem> medications,
  ) async {
    final scope = 'caregiver/$patientId';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          !_medicationApi.isManagedMedicationPhotoPath(medication.photoPath)) {
        result.add(medication);
        continue;
      }
      if (!medication.photoAvailable) {
        await _medicationApi.purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _httpClient.getAuthorizedBytes(
          Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/${medication.id}/photo',
          ),
        );
        final file = await _medicationApi.writeMedicationPhotoFile(
          scope: scope,
          medicationId: medication.id,
          bytes: bytes,
        );
        result.add(medication.copyWith(photoPath: file.path));
      } catch (_) {
        result.add(
          medication.copyWith(photoPath: '', photoAvailable: false),
        );
      }
    }
    return result;
  }

  Future<void> _clearPhotoCache(String userId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/medication_photos/$userId');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

}
