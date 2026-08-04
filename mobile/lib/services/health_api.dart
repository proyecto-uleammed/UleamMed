import '../core/http_client.dart';
import '../models/local_models.dart';
import 'local_store.dart';

/// Dominio de salud del propio paciente: consultas medicas (appointments),
/// contactos de emergencia y registros de salud (condiciones/alergias).
///
/// [appointmentPayload] y [healthEntryPayload] son publicos porque el CRUD
/// proxeado por cuidadores (todavia dentro de `ApiService`) los reutiliza,
/// hasta que `caregiving_api.dart` se extraiga.
class HealthApi {
  HealthApi({
    required this._httpClient,
    required this._localStore,
  });

  final ApiHttpClient _httpClient;
  final LocalStore _localStore;

  Future<List<Appointment>> listAppointments() async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/appointments'),
        fallback: 'No se pudieron cargar las consultas',
      );
      final remote = _httpClient.decodeList(data, Appointment.fromBackendJson);
      final local = await _localStore.readAppointments();
      final pending = local.where(
        (item) =>
            item.syncStatus == SyncStatus.pending &&
            !isPersistedBackendId(item.id),
      );
      final merged = <String, Appointment>{
        for (final item in remote) item.id: item,
        for (final item in pending) item.id: item,
      }.values.toList()..sort(_compareAppointmentsBySchedule);
      await _localStore.saveAppointments(merged);
      return merged;
    } catch (_) {
      return _localStore.readAppointments();
    }
  }

  Future<Appointment> saveAppointment(Appointment appointment) async {
    final localPending = await _localStore.upsertAppointment(
      appointment.copyWith(syncStatus: SyncStatus.pending),
    );
    final isBackendId = isPersistedBackendId(appointment.id);
    final uri = isBackendId
        ? Uri.parse(
            '${_httpClient.baseUrl}/api/v1/appointments/${appointment.id}',
          )
        : Uri.parse('${_httpClient.baseUrl}/api/v1/appointments');
    final body = appointmentPayload(appointment);
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
      final saved = Appointment.fromBackendJson(data);
      if (!isBackendId) {
        await _localStore.deleteAppointment(appointment.id);
      }
      await _localStore.upsertAppointment(saved);
      return saved;
    } catch (_) {
      return localPending;
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    if (isPersistedBackendId(appointmentId)) {
      await _httpClient.deleteAuthorized(
        Uri.parse('${_httpClient.baseUrl}/api/v1/appointments/$appointmentId'),
        fallback: 'No se pudo eliminar la consulta',
      );
    }
    await _localStore.deleteAppointment(appointmentId);
  }

  Future<List<EmergencyContact>> listEmergencyContacts() async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/emergency-contacts'),
        fallback: 'No se pudieron cargar los contactos',
      );
      final remote = _httpClient.decodeList(
        data,
        EmergencyContact.fromBackendJson,
      );
      final local = await _localStore.readEmergencyContacts();
      final pending = local.where(
        (item) =>
            item.syncStatus == SyncStatus.pending &&
            !isPersistedBackendId(item.id),
      );
      final merged = <String, EmergencyContact>{
        for (final item in remote) item.id: item,
        for (final item in pending) item.id: item,
      }.values.toList();
      await _localStore.saveEmergencyContacts(merged);
      return merged;
    } catch (_) {
      return _localStore.readEmergencyContacts();
    }
  }

  Future<EmergencyContact> saveEmergencyContact(
    EmergencyContact contact,
  ) async {
    final localPending = await _localStore.upsertEmergencyContact(
      contact.copyWith(syncStatus: SyncStatus.pending),
    );
    final isBackendId = isPersistedBackendId(contact.id);
    final uri = isBackendId
        ? Uri.parse(
            '${_httpClient.baseUrl}/api/v1/emergency-contacts/${contact.id}',
          )
        : Uri.parse('${_httpClient.baseUrl}/api/v1/emergency-contacts');
    final body = _emergencyContactPayload(contact);
    try {
      final data = isBackendId
          ? await _httpClient.patchAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo actualizar el contacto',
            )
          : await _httpClient.postAuthorizedJson(
              uri,
              body: body,
              fallback: 'No se pudo crear el contacto',
            );
      final saved = EmergencyContact.fromBackendJson(data);
      if (!isBackendId) {
        await _localStore.deleteEmergencyContact(contact.id);
      }
      await _localStore.upsertEmergencyContact(saved);
      return saved;
    } catch (_) {
      return localPending;
    }
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    if (isPersistedBackendId(contactId)) {
      await _httpClient.deleteAuthorized(
        Uri.parse('${_httpClient.baseUrl}/api/v1/emergency-contacts/$contactId'),
        fallback: 'No se pudo eliminar el contacto',
      );
    }
    await _localStore.deleteEmergencyContact(contactId);
  }

  Future<List<HealthEntry>> listHealthEntries() async {
    try {
      final data = await _httpClient.getAuthorizedJson(
        Uri.parse('${_httpClient.baseUrl}/api/v1/health-entries'),
        fallback: 'No se pudieron cargar las condiciones',
      );
      final remote = _httpClient.decodeList(data, HealthEntry.fromBackendJson);
      final local = await _localStore.readHealthEntries();
      final pending = local.where(
        (item) =>
            item.syncStatus == SyncStatus.pending &&
            !isPersistedBackendId(item.id),
      );
      final merged = <String, HealthEntry>{
        for (final item in remote) item.id: item,
        for (final item in pending) item.id: item,
      }.values.toList();
      await _localStore.saveHealthEntries(merged);
      return merged;
    } catch (_) {
      return _localStore.readHealthEntries();
    }
  }

  Future<HealthEntry> saveHealthEntry(HealthEntry entry) async {
    final localPending = await _localStore.upsertHealthEntry(
      entry.copyWith(syncStatus: SyncStatus.pending),
    );
    final isBackendId = isPersistedBackendId(entry.id);
    final uri = isBackendId
        ? Uri.parse('${_httpClient.baseUrl}/api/v1/health-entries/${entry.id}')
        : Uri.parse('${_httpClient.baseUrl}/api/v1/health-entries');
    final body = healthEntryPayload(entry);
    try {
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
      final saved = HealthEntry.fromBackendJson(data);
      if (!isBackendId) {
        await _localStore.deleteHealthEntry(entry.id);
      }
      await _localStore.upsertHealthEntry(saved);
      return saved;
    } catch (_) {
      return localPending;
    }
  }

  Future<void> deleteHealthEntry(String entryId) async {
    if (isPersistedBackendId(entryId)) {
      await _httpClient.deleteAuthorized(
        Uri.parse('${_httpClient.baseUrl}/api/v1/health-entries/$entryId'),
        fallback: 'No se pudo eliminar el registro',
      );
    }
    await _localStore.deleteHealthEntry(entryId);
  }

  int _compareAppointmentsBySchedule(Appointment a, Appointment b) {
    final aDate = a.scheduledAt;
    final bDate = b.scheduledAt;
    if (aDate == null && bDate == null) {
      return 0;
    }
    if (aDate == null) {
      return 1;
    }
    if (bDate == null) {
      return -1;
    }
    return aDate.compareTo(bDate);
  }

  Map<String, dynamic> appointmentPayload(Appointment appointment) {
    final scheduled = appointment.scheduledAt;
    if (scheduled == null) {
      throw const ApiException('La consulta debe tener fecha y hora');
    }
    return {
      'doctor': appointment.doctor,
      'specialty': appointment.specialty,
      'location': appointment.location,
      'notes': appointment.notes,
      'completed': appointment.completed,
      'reminder': appointment.reminder.name,
      'scheduledAt': scheduled.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> healthEntryPayload(HealthEntry entry) {
    return {
      'kind': entry.kind.name,
      'name': entry.name,
      'severity': entry.severity.name,
      'detail': entry.detail,
      'date': entry.date,
      'active': entry.active,
    };
  }

  Map<String, dynamic> _emergencyContactPayload(EmergencyContact contact) {
    return {
      'name': contact.name,
      'phone': contact.phone,
      'relationship': contact.relationship,
      'isPrimary': contact.isPrimary,
    };
  }
}
