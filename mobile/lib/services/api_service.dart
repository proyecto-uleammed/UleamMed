import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';
import '../models/app_role.dart';
import '../models/caregiving_models.dart';
import '../models/local_models.dart';
import 'auth_api.dart';
import 'health_api.dart';
import 'local_store.dart';
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
  }

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  late final AuthApi _authApi;
  late final SyncApi _syncApi;
  late final HealthApi _healthApi;

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
  Future<List<MedicationItem>> listMedications() async {
    final localItems = await _localStore.readMedications();

    try {
      final backendItems = await _loadBackendMedications();
      final conflictItems = await _loadBackendMedicationConflictPlaceholders();
      final activeConflictIds = {
        for (final item in conflictItems)
          if (item.syncConflictId != null) item.syncConflictId!,
      };
      final currentLocalItems = localItems
          .where(
            (item) =>
                item.syncStatus != SyncStatus.conflict ||
                item.syncConflictId == null ||
                activeConflictIds.contains(item.syncConflictId),
          )
          .toList();
      final merged = await _cacheMedicationPhotos(
        _mergeMedications(currentLocalItems, backendItems),
      );
      for (final conflict in conflictItems) {
        if (!merged.any(
          (item) => item.syncConflictId == conflict.syncConflictId,
        )) {
          merged.add(conflict);
        }
      }
      await _localStore.saveMedications(merged);
      return merged;
    } catch (_) {
      return localItems;
    }
  }

  @override
  Future<List<MedicationItem>> listDeletedMedications() async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/medications/trash'),
        fallback: 'No se pudo cargar la papelera',
      );
      return _httpClient.decodeList(data, MedicationItem.fromJson);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<MedicationItem> restoreMedication(String medicationId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/medications/$medicationId/restore'),
      fallback: 'No se pudo restaurar el medicamento',
    );
    final restored = MedicationItem.fromJson(
      data,
    ).copyWith(syncStatus: SyncStatus.synced);
    await _localStore.upsertMedication(restored);
    return restored;
  }

  @override
  Future<MedicationItem?> resolveMedicationSyncConflict(
    int conflictId,
    String resolution,
  ) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/medications/sync-conflicts/$conflictId/resolve',
      ),
      body: {'resolution': resolution},
      fallback: 'No se pudo resolver el duplicado',
      allowEmptyJson: true,
    );
    for (final item in await _localStore.readMedications()) {
      if (item.syncConflictId == conflictId) {
        await _localStore.deleteMedication(item.id);
      }
    }
    if (data.isEmpty) {
      return null;
    }
    final medication = MedicationItem.fromJson(
      data,
    ).copyWith(syncStatus: SyncStatus.synced);
    await _localStore.upsertMedication(medication);
    return medication;
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    return recordMedicationStatus(medicationId, DoseStatus.taken);
  }

  @override
  Future<MedicationItem> saveMedication(MedicationItem medication) async {
    final clientMedicationId = medication.clientMedicationId ?? medication.id;
    final existing = await _findLocalMedication(
      id: medication.id,
      clientMedicationId: clientMedicationId,
    );
    final localPending = await _localStore.upsertMedication(
      medication.copyWith(
        syncStatus: SyncStatus.pending,
        clientMedicationId: clientMedicationId,
      ),
    );
    await _localStore.upsertSyncAction(
      _syncActionForMedication(
        operationType: isPersistedBackendId(medication.id)
            ? SyncActionType.updateMedication
            : SyncActionType.createMedication,
        medication: localPending,
      ),
    );
    try {
      await synchronizePendingChanges();
    } catch (_) {
      // El medicamento queda guardado localmente y pendiente de sincronizar.
    }
    var result =
        await _findLocalMedication(
          id: localPending.id,
          clientMedicationId: clientMedicationId,
        ) ??
        localPending;
    if (isPersistedBackendId(result.id)) {
      result = await _syncMedicationPhoto(result, localPending, existing);
    }
    return result;
  }

  PendingSyncAction _syncActionForMedication({
    required SyncActionType operationType,
    required MedicationItem medication,
    int? patientId,
    String actorRole = 'patient',
  }) {
    return PendingSyncAction(
      clientOperationId: _clientOperationId(operationType.name),
      operationType: operationType,
      createdAt: DateTime.now(),
      payload: operationType == SyncActionType.deleteMedication
          ? const {}
          : _medicationPayload(medication),
      clientMedicationId: medication.clientMedicationId ?? medication.id,
      serverMedicationId: isPersistedBackendId(medication.id)
          ? medication.id
          : null,
      patientId: patientId,
      actorRole: actorRole,
    );
  }

  Map<String, dynamic> _medicationPayload(MedicationItem medication) {
    return {
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
      'clientMedicationId': medication.clientMedicationId ?? medication.id,
      if (isPersistedBackendId(medication.id)) 'taken': medication.taken,
    };
  }

  Future<MedicationItem?> _findLocalMedication({
    required String id,
    String? clientMedicationId,
  }) async {
    for (final item in await _localStore.readMedications()) {
      if (item.id == id ||
          (clientMedicationId != null &&
              item.clientMedicationId == clientMedicationId)) {
        return item;
      }
    }
    return null;
  }

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

  String _clientOperationId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
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
        await _httpClient.deleteAuthorized(
          Uri.parse('${_httpClient.baseUrl}/api/v1/medications/${saved.id}/photo'),
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
    final existing = await _findLocalMedication(id: medicationId);
    await _localStore.deleteMedication(medicationId);
    if (existing == null) {
      return;
    }
    await _localStore.upsertSyncAction(
      _syncActionForMedication(
        operationType: SyncActionType.deleteMedication,
        medication: existing,
      ),
    );
    await _localStore.deleteDoseConfirmationsForMedication(medicationId);
    unawaited(synchronizePendingChanges());
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
    await _localStore.upsertSyncAction(
      PendingSyncAction(
        clientOperationId: confirmation.id,
        operationType: SyncActionType.doseEvent,
        createdAt: confirmation.recordedAt,
        payload: {
          'client_event_id': confirmation.id,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'sequence_number': sequenceNumber,
          'status': status.name,
          'acted_at': confirmation.recordedAt.toUtc().toIso8601String(),
          'snoozed_until': snoozedUntil?.toUtc().toIso8601String(),
        },
        clientMedicationId: medication.clientMedicationId ?? medication.id,
        serverMedicationId: isPersistedBackendId(medication.id)
            ? medication.id
            : null,
        actorRole: 'patient',
      ),
    );

    final localResult = await _medicationResultFor(updated.id);
    try {
      await synchronizePendingChanges();
      return _medicationResultFor(updated.id);
    } catch (_) {
      return localResult;
    }
  }

  @override
  Future<List<DoseConfirmation>> listDoseConfirmations() async {
    final local = await _localStore.readDoseConfirmations();
    try {
      final data = await _httpClient.getAuthorizedList(
        Uri.parse('${_httpClient.baseUrl}/api/v1/medications/dose-events'),
        fallback: 'No se pudo cargar el historial',
      );
      final remote = data
          .whereType<Map>()
          .map(
            (json) => DoseConfirmation.fromBackendEvent(
              Map<String, dynamic>.from(json),
            ),
          )
          .toList();
      return _mergeDoseConfirmations(local, remote);
    } catch (_) {
      return local;
    }
  }

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
      final merged = _mergeMedications(localItems, backendItems);
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
      _syncActionForMedication(
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
      _syncActionForMedication(
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
  Future<int> clearDoseHistory({DateTime? before}) async {
    final uri = before == null
        ? Uri.parse('${_httpClient.baseUrl}/api/v1/medications/dose-events')
        : Uri.parse(
            '${_httpClient.baseUrl}/api/v1/medications/dose-events?before=${Uri.encodeComponent(before.toUtc().toIso8601String())}',
          );
    final data = await _deleteAuthorizedJson(
      uri,
      fallback: 'No se pudo limpiar el historial',
    );
    return data['deleted'] as int? ?? 0;
  }

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
        await _purgeMedicationPhotoCache(scope, saved.id);
        final cleared = saved.copyWith(photoAvailable: false, photoPath: '');
        await _localStore.upsertCaregiverPatientMedication(patientId, cleared);
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
        await _localStore.upsertCaregiverPatientMedication(patientId, saved);
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
          contentType: _photoContentType(path),
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
        ? await _findLocalMedication(
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
        await _syncMedicationPhoto(
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
      final current = await _findLocalMedication(
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

  Future<List<MedicationItem>> _loadBackendMedications() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/medications'),
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

  Future<List<MedicationItem>>
  _loadBackendMedicationConflictPlaceholders() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/medications/sync-conflicts'),
      fallback: 'No se pudieron cargar los conflictos',
    );
    final items = data['items'];
    if (items is! List) {
      return const [];
    }
    return items.whereType<Map>().map((raw) {
      final json = Map<String, dynamic>.from(raw);
      final conflictId = int.tryParse(json['id']?.toString() ?? '');
      final incomingName =
          json['incomingMedicationName']?.toString() ?? 'Medicamento';
      final candidateName = json['candidateMedicationName']?.toString();
      return MedicationItem(
        id: 'conflict-${conflictId ?? incomingName}',
        name: incomingName,
        dose: 'Revisar duplicado',
        time: '',
        taken: false,
        frequency: '',
        duration: '',
        syncStatus: SyncStatus.conflict,
        syncConflictId: conflictId,
        lastSyncError: candidateName == null
            ? 'Posible duplicado pendiente de revisar.'
            : 'Se parece a $candidateName. Decide si fusionar o crear aparte.',
      );
    }).toList();
  }

  List<MedicationItem> _mergeMedications(
    List<MedicationItem> localItems,
    List<MedicationItem> backendItems,
  ) {
    final byId = <String, MedicationItem>{
      for (final item in backendItems) item.id: item,
    };
    for (final local in localItems) {
      if (local.syncStatus == SyncStatus.pending ||
          local.syncStatus == SyncStatus.conflict ||
          local.syncStatus == SyncStatus.syncing) {
        if (int.tryParse(local.id) != null) {
          byId[local.id] = local;
        } else {
          byId[local.id] = local;
        }
        continue;
      }

      final backend = byId[local.id];
      if (backend != null) {
        final cachedPhoto = local.photoPath;
        final photoExists =
            cachedPhoto.isNotEmpty && File(cachedPhoto).existsSync();
        final keepPhoto =
            photoExists &&
            (backend.photoAvailable ||
                !_isManagedMedicationPhotoPath(cachedPhoto));
        byId[local.id] = backend.copyWith(
          taken: backend.taken,
          photoPath: keepPhoto ? cachedPhoto : '',
        );
      }
    }
    return byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  List<DoseConfirmation> _mergeDoseConfirmations(
    List<DoseConfirmation> local,
    List<DoseConfirmation> remote,
  ) {
    final byId = <String, DoseConfirmation>{
      for (final item in remote) item.id: item,
    };
    for (final item in local) {
      if (item.syncStatus == SyncStatus.pending || !byId.containsKey(item.id)) {
        byId[item.id] = item;
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
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

  Future<List<MedicationItem>> _cacheMedicationPhotos(
    List<MedicationItem> medications,
  ) async {
    final scope = await _localStore.readActiveUserId() ?? 'unknown';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          !_isManagedMedicationPhotoPath(medication.photoPath)) {
        result.add(medication);
        continue;
      }
      if (!medication.photoAvailable) {
        await _purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _getAuthorizedBytes(
          Uri.parse('${_httpClient.baseUrl}/api/v1/medications/${medication.id}/photo'),
        );
        final file = await _writeMedicationPhotoFile(
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

  Future<List<MedicationItem>> _cacheCaregiverPatientMedicationPhotos(
    int patientId,
    List<MedicationItem> medications,
  ) async {
    final scope = 'caregiver/$patientId';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          !_isManagedMedicationPhotoPath(medication.photoPath)) {
        result.add(medication);
        continue;
      }
      if (!medication.photoAvailable) {
        await _purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _getAuthorizedBytes(
          Uri.parse(
            '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/${medication.id}/photo',
          ),
        );
        final file = await _writeMedicationPhotoFile(
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
        Uri.parse('${_httpClient.baseUrl}/api/v1/medications/$medicationId/photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          path,
          contentType: _photoContentType(path),
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

  MediaType _photoContentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  Future<List<int>> _getAuthorizedBytes(Uri uri) async {
    final token = await _httpClient.ensureAccessToken();
    var response = await _httpClient.client.get(
      uri,
      headers: _httpClient.authorizedHeaders(token),
    );
    if (response.statusCode == 401 &&
        await _httpClient.refreshAccessToken(staleToken: token)) {
      response = await _httpClient.client.get(
        uri,
        headers: _httpClient.authorizedHeaders(await _httpClient.ensureAccessToken()),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('No se pudo descargar la foto', response.statusCode);
    }
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      throw ApiException('Sin foto disponible', 204);
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

}