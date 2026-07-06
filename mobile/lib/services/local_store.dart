import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/local_models.dart';

abstract class JsonStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureJsonStore implements JsonStore {
  SecureJsonStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class LocalStore {
  LocalStore({JsonStore? jsonStore}) : _jsonStore = jsonStore ?? SecureJsonStore();

  final JsonStore _jsonStore;

  static const _medicalProfileKey = 'uleammed_medical_profile';
  static const _medicationsKey = 'uleammed_medications';
  static const _confirmationsKey = 'uleammed_dose_confirmations';
  static const _appointmentsKey = 'uleammed_appointments';
  static const _emergencyContactsKey = 'uleammed_emergency_contacts';
  static const _caregiverPermissionsKey = 'uleammed_caregiver_permissions';

  Future<MedicalProfile> readMedicalProfile() async {
    final data = await _readObject(_medicalProfileKey);
    if (data == null) {
      return const MedicalProfile();
    }
    return MedicalProfile.fromJson(data);
  }

  Future<void> saveMedicalProfile(MedicalProfile profile) async {
    final now = DateTime.now();
    final current = await readMedicalProfile();
    final saved = profile.copyWith(
      syncStatus: SyncStatus.pending,
      createdAt: profile.createdAt ?? current.createdAt ?? now,
      updatedAt: now,
    );
    return _writeObject(_medicalProfileKey, saved.toJson());
  }

  Future<List<MedicationItem>> readMedications() {
    return _readList(
      _medicationsKey,
      (json) => MedicationItem.fromJson(json),
    );
  }

  Future<void> saveMedications(List<MedicationItem> medications) {
    return _writeList(
      _medicationsKey,
      medications.map((medication) => medication.toJson()).toList(),
    );
  }

  Future<MedicationItem> upsertMedication(MedicationItem medication) async {
    final now = DateTime.now();
    final normalized = medication.copyWith(
      createdAt: medication.createdAt ?? now,
      updatedAt: now,
    );
    final medications = await readMedications();
    final index = medications.indexWhere((item) => item.id == medication.id);
    if (index >= 0) {
      medications[index] = normalized;
    } else {
      medications.add(normalized);
    }
    await saveMedications(medications);
    return normalized;
  }

  Future<void> deleteMedication(String medicationId) async {
    final medications = await readMedications();
    await saveMedications(
      medications.where((item) => item.id != medicationId).toList(),
    );
  }

  Future<List<DoseConfirmation>> readDoseConfirmations() {
    return _readList(
      _confirmationsKey,
      (json) => DoseConfirmation.fromJson(json),
    );
  }

  Future<void> addDoseConfirmation(DoseConfirmation confirmation) async {
    final confirmations = await readDoseConfirmations();
    confirmations.insert(0, confirmation);
    await _writeList(
      _confirmationsKey,
      confirmations.map((item) => item.toJson()).toList(),
    );
  }

  Future<List<Appointment>> readAppointments() {
    return _readList(_appointmentsKey, (json) => Appointment.fromJson(json));
  }

  Future<void> saveAppointments(List<Appointment> appointments) {
    return _writeList(
      _appointmentsKey,
      appointments.map((appointment) => appointment.toJson()).toList(),
    );
  }

  Future<List<EmergencyContact>> readEmergencyContacts() {
    return _readList(
      _emergencyContactsKey,
      (json) => EmergencyContact.fromJson(json),
    );
  }

  Future<void> saveEmergencyContacts(List<EmergencyContact> contacts) {
    return _writeList(
      _emergencyContactsKey,
      contacts.map((contact) => contact.toJson()).toList(),
    );
  }

  Future<EmergencyContact> upsertEmergencyContact(
    EmergencyContact contact,
  ) async {
    final normalized = contact.copyWith(syncStatus: SyncStatus.pending);
    var contacts = await readEmergencyContacts();
    if (normalized.isPrimary) {
      contacts = contacts
          .map((item) => item.copyWith(isPrimary: false))
          .toList();
    }
    final index = contacts.indexWhere((item) => item.id == normalized.id);
    if (index >= 0) {
      contacts[index] = normalized;
    } else {
      contacts.add(normalized);
    }
    await saveEmergencyContacts(contacts);
    return normalized;
  }

  Future<void> deleteEmergencyContact(String id) async {
    final contacts = await readEmergencyContacts();
    await saveEmergencyContacts(
      contacts.where((item) => item.id != id).toList(),
    );
  }

  Future<List<CaregiverPermission>> readCaregiverPermissions() {
    return _readList(
      _caregiverPermissionsKey,
      (json) => CaregiverPermission.fromJson(json),
    );
  }

  Future<int> pendingSyncCount() async {
    var total = 0;
    final profile = await readMedicalProfile();
    if (profile.syncStatus == SyncStatus.pending) {
      total++;
    }
    total += (await readMedications())
        .where((item) => item.syncStatus == SyncStatus.pending)
        .length;
    total += (await readDoseConfirmations())
        .where((item) => item.syncStatus == SyncStatus.pending)
        .length;
    total += (await readAppointments())
        .where((item) => item.syncStatus == SyncStatus.pending)
        .length;
    total += (await readEmergencyContacts())
        .where((item) => item.syncStatus == SyncStatus.pending)
        .length;
    total += (await readCaregiverPermissions())
        .where((item) => item.syncStatus == SyncStatus.pending)
        .length;
    return total;
  }

  Future<Map<String, dynamic>?> _readObject(String key) async {
    final raw = await _jsonStore.read(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    final raw = await _jsonStore.read(key);
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded.whereType<Map>().map((item) {
      return fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<void> _writeObject(String key, Map<String, dynamic> value) {
    return _jsonStore.write(key, jsonEncode(value));
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> value) {
    return _jsonStore.write(key, jsonEncode(value));
  }
}
