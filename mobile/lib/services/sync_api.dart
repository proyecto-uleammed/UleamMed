import '../core/http_client.dart';
import '../models/local_models.dart';
import 'local_store.dart';

/// Dominio de sincronizacion offline -> backend.
///
/// Envia en lotes las [PendingSyncAction] pendientes que guardo [LocalStore]
/// mientras el dispositivo estaba sin conexion. La interpretacion de cada
/// resultado (aplicar el medicamento sincronizado, marcar conflicto, etc.)
/// sigue siendo responsabilidad del dominio de medicamentos/cuidado: se
/// inyecta via [applySyncResults] hasta que `medication_api.dart` y
/// `caregiving_api.dart` se extraigan de `ApiService`.
class SyncApi {
  SyncApi({
    required this._httpClient,
    required this._localStore,
    required this._applySyncResults,
  });

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;
  final Future<int> Function(
    Map<String, dynamic> data,
    List<PendingSyncAction> actions, {
    int? caregiverPatientId,
  })
  _applySyncResults;

  Future<int> pendingSyncCount() {
    return _localStore.pendingSyncCount();
  }

  Future<SyncSummary> synchronizePendingChanges() async {
    var processed = 0;
    final actions =
        (await _localStore.readSyncActions())
            .where((item) => item.syncStatus == SyncStatus.pending)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final patientActions = actions
        .where((item) => item.patientId == null)
        .toList();
    if (patientActions.isNotEmpty) {
      processed += await _syncActionBatch(
        Uri.parse('${_httpClient.baseUrl}/api/v1/medications/sync'),
        patientActions,
      );
    }

    final caregiverPatientIds = {
      for (final action in actions)
        if (action.patientId != null) action.patientId!,
    };
    for (final patientId in caregiverPatientIds) {
      final caregiverActions = actions
          .where((item) => item.patientId == patientId)
          .toList();
      processed += await _syncActionBatch(
        Uri.parse(
          '${_httpClient.baseUrl}/api/v1/caregiving/patients/$patientId/medications/sync',
        ),
        caregiverActions,
        caregiverPatientId: patientId,
      );
    }

    final pending = await _localStore.pendingSyncCount();
    return SyncSummary(
      processed: processed,
      pending: pending,
      message: pending == 0
          ? 'Todo esta sincronizado.'
          : 'Quedan $pending cambios por sincronizar.',
    );
  }

  Future<int> _syncActionBatch(
    Uri uri,
    List<PendingSyncAction> actions, {
    int? caregiverPatientId,
  }) async {
    if (actions.isEmpty) {
      return 0;
    }
    for (final action in actions) {
      await _localStore.upsertSyncAction(
        action.copyWith(syncStatus: SyncStatus.syncing),
      );
    }
    try {
      final data = await _httpClient.postAuthorizedJson(
        uri,
        body: {'actions': actions.map((item) => item.toApiJson()).toList()},
        fallback: 'No se pudieron sincronizar los medicamentos',
      );
      return _applySyncResults(
        data,
        actions,
        caregiverPatientId: caregiverPatientId,
      );
    } catch (error) {
      for (final action in actions) {
        await _localStore.upsertSyncAction(
          action.copyWith(
            syncStatus: SyncStatus.pending,
            retryCount: action.retryCount + 1,
            lastError: error is ApiException
                ? error.message
                : 'No se pudo sincronizar',
          ),
        );
      }
      return 0;
    }
  }
}
