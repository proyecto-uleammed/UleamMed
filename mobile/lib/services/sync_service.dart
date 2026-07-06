import '../models/local_models.dart';
import 'local_store.dart';

class SyncService {
  const SyncService({required LocalStore localStore}) : _localStore = localStore;

  final LocalStore _localStore;

  Future<SyncSummary> synchronizePending() async {
    final pending = await _localStore.pendingSyncCount();
    if (pending == 0) {
      return const SyncSummary(
        processed: 0,
        pending: 0,
        message: 'Todo esta sincronizado.',
      );
    }

    return SyncSummary(
      processed: 0,
      pending: pending,
      message:
          'Hay $pending cambios locales pendientes hasta que existan endpoints de sincronizacion.',
    );
  }
}
