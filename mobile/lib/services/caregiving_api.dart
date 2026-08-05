import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/http_client.dart';
import '../models/caregiving_models.dart';
import '../models/local_models.dart';
import 'health_api.dart';
import 'local_store.dart';
import 'medication_api.dart';

/// Dominio de vinculo cuidador-paciente: invitaciones, aprobacion/rechazo
/// de vinculos, y CRUD proxeado (medicamentos, dosis, consultas, contactos
/// de emergencia, registros de salud, perfil medico) para los pacientes
/// que un cuidador supervisa.
///
/// [findLocalCaregiverMedication] y [syncCaregiverPatientMedicationPhoto]
/// son publicos porque `ApiService` los reutiliza al interpretar resultados
/// de sincronizacion (`_applySyncedMedicationResult`/`_markMedicationConflict`),
/// que coordinan tanto el dominio de medicamentos propios como el de
/// cuidadores.
class CaregivingApi {
  CaregivingApi({
    required this._httpClient,
    required this._localStore,
    required this._medicationApi,
    required this._healthApi,
    required this._synchronizePendingChanges,
  });

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  final MedicationApi _medicationApi;
  final HealthApi _healthApi;
  final Future<SyncSummary> Function() _synchronizePendingChanges;

  // --- Invitaciones y vinculos ---

  Future<CaregiverInvitation> createCaregiverInvitation() async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/invitations'),
      fallback: 'No se pudo generar el codigo',
    );
    return CaregiverInvitation.fromJson(data);
  }

  Future<void> cancelCaregiverInvitation(int invitationId) {
    return _httpClient.deleteAuthorized(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/invitations/$invitationId',
      ),
      fallback: 'No se pudo cancelar el codigo',
    );
  }

  Future<CaregiverLink> redeemCaregiverInvitation(String code) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/invitations/redeem'),
      body: {'code': code.trim()},
      fallback: 'No se pudo enviar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  Future<List<CaregiverLink>> listCaregivingLinks() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links'),
      fallback: 'No se pudieron cargar los vinculos',
    );
    return _httpClient.decodeList(data, CaregiverLink.fromJson);
  }

  Future<CaregiverLink> approveCaregiverLink(int linkId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId/approve',
      ),
      fallback: 'No se pudo aprobar al cuidador',
    );
    return CaregiverLink.fromJson(data);
  }

  Future<CaregiverLink> rejectCaregiverLink(int linkId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId/reject',
      ),
      fallback: 'No se pudo rechazar la solicitud',
    );
    return CaregiverLink.fromJson(data);
  }

  Future<void> revokeCaregiverLink(int linkId) {
    return _httpClient.deleteAuthorized(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/links/$linkId'),
      fallback: 'No se pudo revocar el acceso',
    );
  }

  Future<List<CaregiverPatient>> listCaregiverPatients() async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse('${_httpClient.baseUrl}/api/v1/caregiving/patients'),
      fallback: 'No se pudieron cargar los pacientes',
    );
    return _httpClient.decodeList(data, CaregiverPatient.fromJson);
  }

  // --- Medicamentos proxeados ---

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

  Future<MedicationItem> saveCaregiverPatientMedication(
    int patientId,
    MedicationItem medication,
  ) async {
    final clientMedicationId = medication.clientMedicationId ?? medication.id;
    final existing = await findLocalCaregiverMedication(
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
      await _synchronizePendingChanges();
    } catch (_) {
      // Conserva el cambio local del cuidador hasta recuperar conexion.
    }
    var result =
        await findLocalCaregiverMedication(
          patientId,
          id: localPending.id,
          clientMedicationId: clientMedicationId,
        ) ??
        localPending;
    if (isPersistedBackendId(result.id)) {
      result = await syncCaregiverPatientMedicationPhoto(
        patientId: patientId,
        saved: result,
        medication: localPending,
        existing: existing,
      );
      await _localStore.upsertCaregiverPatientMedication(patientId, result);
    }
    return result;
  }

  Future<void> deleteCaregiverPatientMedication(
    int patientId,
    String medicationId,
  ) async {
    final existing = await findLocalCaregiverMedication(
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
    unawaited(_synchronizePendingChanges());
  }

  Future<void> recordCaregiverPatientDoseEvent({
    required int patientId,
    required String medicationId,
    required DoseStatus status,
    required DateTime scheduledAt,
    required int sequenceNumber,
    DateTime? snoozedUntil,
  }) async {
    final recordedAt = DateTime.now();
    final medication = await findLocalCaregiverMedication(
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
    unawaited(_synchronizePendingChanges());
  }

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
    final data = await _httpClient.authorizedJson(
      request: (token) => _httpClient.client.delete(
        uri,
        headers: _httpClient.authorizedHeaders(token),
      ),
      fallback: 'No se pudo limpiar el historial',
    );
    return data['deleted'] as int? ?? 0;
  }

  // --- Consultas, contactos y salud proxeados ---

  Future<List<Appointment>> listCaregiverPatientAppointments(
    int patientId,
  ) async {
    final data = await _httpClient.getAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/appointments',
      ),
      fallback: 'No se pudieron cargar las consultas',
    );
    return _httpClient.decodeList(data, Appointment.fromBackendJson);
  }

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

  // --- Compartido con el glue de sincronizacion (ApiService) ---

  Future<MedicationItem?> findLocalCaregiverMedication(
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

  Future<MedicationItem> syncCaregiverPatientMedicationPhoto({
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

  // --- Privados: solo los usa este archivo ---

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
}
