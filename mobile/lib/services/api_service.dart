import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';
import '../models/app_role.dart';
import '../models/caregiving_models.dart';
import '../models/local_models.dart';
import 'auth_api.dart';
import 'caregiving_api.dart';
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
    _caregivingApi = CaregivingApi(
      httpClient: _httpClient,
      localStore: _localStore,
      medicationApi: _medicationApi,
      healthApi: _healthApi,
      synchronizePendingChanges: _syncApi.synchronizePendingChanges,
    );
  }

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  late final AuthApi _authApi;
  late final SyncApi _syncApi;
  late final HealthApi _healthApi;
  late final MedicationApi _medicationApi;
  late final CaregivingApi _caregivingApi;

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
  Future<CaregiverInvitation> createCaregiverInvitation() =>
      _caregivingApi.createCaregiverInvitation();

  @override
  Future<void> cancelCaregiverInvitation(int invitationId) =>
      _caregivingApi.cancelCaregiverInvitation(invitationId);

  @override
  Future<CaregiverLink> redeemCaregiverInvitation(String code) =>
      _caregivingApi.redeemCaregiverInvitation(code);

  @override
  Future<List<CaregiverLink>> listCaregivingLinks() =>
      _caregivingApi.listCaregivingLinks();

  @override
  Future<CaregiverLink> approveCaregiverLink(int linkId) =>
      _caregivingApi.approveCaregiverLink(linkId);

  @override
  Future<CaregiverLink> rejectCaregiverLink(int linkId) =>
      _caregivingApi.rejectCaregiverLink(linkId);

  @override
  Future<void> revokeCaregiverLink(int linkId) =>
      _caregivingApi.revokeCaregiverLink(linkId);

  @override
  Future<List<CaregiverPatient>> listCaregiverPatients() =>
      _caregivingApi.listCaregiverPatients();

  @override
  Future<List<MedicationItem>> listCaregiverPatientMedications(
    int patientId,
  ) => _caregivingApi.listCaregiverPatientMedications(patientId);

  @override
  Future<MedicationItem> saveCaregiverPatientMedication(
    int patientId,
    MedicationItem medication,
  ) => _caregivingApi.saveCaregiverPatientMedication(patientId, medication);

  @override
  Future<void> deleteCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) => _caregivingApi.deleteCaregiverPatientMedication(patientId, medicationId);

  @override
  Future<void> recordCaregiverPatientDoseEvent({
    required int patientId,
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) => _caregivingApi.recordCaregiverPatientDoseEvent(
    patientId: patientId,
    medicationId: medicationId,
    status: status,
    scheduledAt: scheduledAt,
    sequenceNumber: sequenceNumber,
    snoozedUntil: snoozedUntil,
  );

  @override
  Future<List<MedicationItem>> listCaregiverPatientDeletedMedications(
    int patientId,
  ) => _caregivingApi.listCaregiverPatientDeletedMedications(patientId);

  @override
  Future<MedicationItem> restoreCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) => _caregivingApi.restoreCaregiverPatientMedication(
    patientId,
    medicationId,
  );

  @override
  Future<List<Appointment>> listCaregiverPatientAppointments(int patientId) =>
      _caregivingApi.listCaregiverPatientAppointments(patientId);

  @override
  Future<Appointment> saveCaregiverPatientAppointment(
    int patientId,
    Appointment appointment,
  ) => _caregivingApi.saveCaregiverPatientAppointment(patientId, appointment);

  @override
  Future<void> deleteCaregiverPatientAppointment(
    int patientId,
    String appointmentId,
  ) => _caregivingApi.deleteCaregiverPatientAppointment(
    patientId,
    appointmentId,
  );

  @override
  Future<List<HealthEntry>> listCaregiverPatientHealthEntries(
    int patientId,
  ) => _caregivingApi.listCaregiverPatientHealthEntries(patientId);

  @override
  Future<HealthEntry> saveCaregiverPatientHealthEntry(
    int patientId,
    HealthEntry entry,
  ) => _caregivingApi.saveCaregiverPatientHealthEntry(patientId, entry);

  @override
  Future<void> deleteCaregiverPatientHealthEntry(
    int patientId,
    String entryId,
  ) => _caregivingApi.deleteCaregiverPatientHealthEntry(patientId, entryId);

  @override
  Future<MedicalProfile> loadCaregiverPatientMedicalProfile(int patientId) =>
      _caregivingApi.loadCaregiverPatientMedicalProfile(patientId);

  @override
  Future<List<EmergencyContact>> listCaregiverPatientEmergencyContacts(
    int patientId,
  ) => _caregivingApi.listCaregiverPatientEmergencyContacts(patientId);

  @override
  Future<int> clearDoseHistory({DateTime? before}) =>
      _medicationApi.clearDoseHistory(before: before);

  @override
  Future<int> clearCaregiverPatientDoseHistory(
    int patientId, {
    DateTime? before,
  }) => _caregivingApi.clearCaregiverPatientDoseHistory(
    patientId,
    before: before,
  );

  @override
  Future<List<DoseConfirmation>> listCaregiverPatientDoseEvents(
    int patientId,
  ) => _caregivingApi.listCaregiverPatientDoseEvents(patientId);

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
        : await _caregivingApi.findLocalCaregiverMedication(
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
        final synced = await _caregivingApi.syncCaregiverPatientMedicationPhoto(
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
    final current = await _caregivingApi.findLocalCaregiverMedication(
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

  Future<void> _clearPhotoCache(String userId) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/medication_photos/$userId');
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

}
