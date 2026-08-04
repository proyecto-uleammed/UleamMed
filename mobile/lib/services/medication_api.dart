import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import '../core/http_client.dart';
import '../models/local_models.dart';
import 'local_store.dart';

/// Dominio de medicamentos del propio paciente: CRUD, papelera, dosis
/// (registro y confirmaciones) y cache local de fotos.
///
/// Varios metodos son publicos aunque nada dentro de este archivo los
/// invoca fuera de si mismo: el CRUD de medicamentos proxeado por
/// cuidadores (todavia dentro de `ApiService`) los reutiliza, hasta que
/// `caregiving_api.dart` se extraiga. Son: [findLocalMedication],
/// [syncMedicationPhoto], [syncActionForMedication], [mergeMedications],
/// [purgeMedicationPhotoCache], [writeMedicationPhotoFile],
/// [isManagedMedicationPhotoPath], [shouldUploadMedicationPhoto] y
/// [photoContentType].
class MedicationApi {
  MedicationApi({
    required this._httpClient,
    required this._localStore,
    required this._synchronizePendingChanges,
  });

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  final Future<SyncSummary> Function() _synchronizePendingChanges;

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
        mergeMedications(currentLocalItems, backendItems),
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

  Future<MedicationItem> restoreMedication(String medicationId) async {
    final data = await _httpClient.postAuthorizedJson(
      Uri.parse(
        '${_httpClient.baseUrl}/api/v1/medications/$medicationId/restore',
      ),
      fallback: 'No se pudo restaurar el medicamento',
    );
    final restored = MedicationItem.fromJson(
      data,
    ).copyWith(syncStatus: SyncStatus.synced);
    await _localStore.upsertMedication(restored);
    return restored;
  }

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

  Future<MedicationMarkResult> markMedicationTaken(String medicationId) {
    return recordMedicationStatus(medicationId, DoseStatus.taken);
  }

  Future<MedicationItem> saveMedication(MedicationItem medication) async {
    final clientMedicationId = medication.clientMedicationId ?? medication.id;
    final existing = await findLocalMedication(
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
      syncActionForMedication(
        operationType: isPersistedBackendId(medication.id)
            ? SyncActionType.updateMedication
            : SyncActionType.createMedication,
        medication: localPending,
      ),
    );
    try {
      await _synchronizePendingChanges();
    } catch (_) {
      // El medicamento queda guardado localmente y pendiente de sincronizar.
    }
    var result =
        await findLocalMedication(
          id: localPending.id,
          clientMedicationId: clientMedicationId,
        ) ??
        localPending;
    if (isPersistedBackendId(result.id)) {
      result = await syncMedicationPhoto(result, localPending, existing);
    }
    return result;
  }

  Future<void> deleteMedication(String medicationId) async {
    final existing = await findLocalMedication(id: medicationId);
    await _localStore.deleteMedication(medicationId);
    if (existing == null) {
      return;
    }
    await _localStore.upsertSyncAction(
      syncActionForMedication(
        operationType: SyncActionType.deleteMedication,
        medication: existing,
      ),
    );
    await _localStore.deleteDoseConfirmationsForMedication(medicationId);
    unawaited(_synchronizePendingChanges());
  }

  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  ) {
    return recordScheduledDose(
      medicationId: medicationId,
      status: status,
      scheduledAt: DateTime.now(),
      sequenceNumber: 1,
    );
  }

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
      await _synchronizePendingChanges();
      return _medicationResultFor(updated.id);
    } catch (_) {
      return localResult;
    }
  }

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

  Future<int> clearDoseHistory({DateTime? before}) async {
    final uri = before == null
        ? Uri.parse('${_httpClient.baseUrl}/api/v1/medications/dose-events')
        : Uri.parse(
            '${_httpClient.baseUrl}/api/v1/medications/dose-events?before=${Uri.encodeComponent(before.toUtc().toIso8601String())}',
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

  // --- Compartido con el CRUD proxeado por cuidadores (ApiService) ---

  Future<MedicationItem?> findLocalMedication({
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

  Future<MedicationItem> syncMedicationPhoto(
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
          Uri.parse(
            '${_httpClient.baseUrl}/api/v1/medications/${saved.id}/photo',
          ),
          fallback: 'No se pudo eliminar la foto',
        );
        await purgeMedicationPhotoCache(userId, saved.id);
        final cleared = saved.copyWith(photoAvailable: false, photoPath: '');
        await _localStore.upsertMedication(cleared);
        return cleared;
      }

      final shouldUpload =
          medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          shouldUploadMedicationPhoto(
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
      final cachedFile = await writeMedicationPhotoFile(
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

  PendingSyncAction syncActionForMedication({
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

  List<MedicationItem> mergeMedications(
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
                !isManagedMedicationPhotoPath(cachedPhoto));
        byId[local.id] = backend.copyWith(
          taken: backend.taken,
          photoPath: keepPhoto ? cachedPhoto : '',
        );
      }
    }
    return byId.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }

  bool shouldUploadMedicationPhoto({
    required String localPhotoPath,
    required bool hadPhotoAvailable,
  }) {
    if (!isManagedMedicationPhotoPath(localPhotoPath)) {
      return true;
    }
    return !hadPhotoAvailable;
  }

  bool isManagedMedicationPhotoPath(String path) {
    return path.replaceAll('\\', '/').contains('/medication_photos/');
  }

  Future<void> purgeMedicationPhotoCache(
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

  Future<File> writeMedicationPhotoFile({
    required String scope,
    required String medicationId,
    required List<int> bytes,
  }) async {
    await purgeMedicationPhotoCache(scope, medicationId);
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/medication_photos/$scope');
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}/$medicationId-${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  MediaType photoContentType(String path) {
    final extension = path.toLowerCase().split('.').last;
    return switch (extension) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  // --- Privados: solo los usa este archivo ---

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

  Future<List<MedicationItem>> _cacheMedicationPhotos(
    List<MedicationItem> medications,
  ) async {
    final scope = await _localStore.readActiveUserId() ?? 'unknown';
    final result = <MedicationItem>[];
    for (final medication in medications) {
      if (medication.photoPath.isNotEmpty &&
          File(medication.photoPath).existsSync() &&
          !isManagedMedicationPhotoPath(medication.photoPath)) {
        result.add(medication);
        continue;
      }
      if (!medication.photoAvailable) {
        await purgeMedicationPhotoCache(scope, medication.id);
        result.add(medication.copyWith(photoPath: ''));
        continue;
      }
      try {
        final bytes = await _httpClient.getAuthorizedBytes(
          Uri.parse(
            '${_httpClient.baseUrl}/api/v1/medications/${medication.id}/photo',
          ),
        );
        final file = await writeMedicationPhotoFile(
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

  Future<Map<String, dynamic>> _uploadMedicationPhoto(
    String medicationId,
    String path,
  ) async {
    Future<http.StreamedResponse> send(String token) async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          '${_httpClient.baseUrl}/api/v1/medications/$medicationId/photo',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          path,
          contentType: photoContentType(path),
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

  String _clientOperationId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
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
}
