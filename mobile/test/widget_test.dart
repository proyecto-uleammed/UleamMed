import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uleam_med/main.dart';
import 'package:uleam_med/services/api_service.dart';
import 'package:uleam_med/services/app_settings.dart';
import 'package:uleam_med/services/local_store.dart';

class _MemoryJsonStore implements JsonStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

AppSettingsController _testSettings() {
  final store = _MemoryJsonStore();
  store.values['uleammed_app_settings'] = '{"onboardingSeen":true}';
  return AppSettingsController(AppSettingsService(store: store));
}

Future<void> _loginWithForm(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Correo electrónico'),
    'roberto@uleammed.test',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña'),
    'clave-segura-123',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
  await tester.pumpAndSettle();
}

class _FakeApi implements UleamMedApi {
  _FakeApi({this.restoredSession});

  AppSession? restoredSession;
  AppSession? currentSession;
  bool didLogout = false;
  MedicalProfile medicalProfile = const MedicalProfile();
  final List<DoseConfirmation> confirmations = [];
  final List<MedicationItem> medications = [
    const MedicationItem(
      id: 'metformina',
      name: 'Metformina',
      dose: '500 mg',
      time: '08:00',
      taken: true,
    ),
    const MedicationItem(
      id: 'omeprazol',
      name: 'Omeprazol',
      dose: '20 mg',
      time: '14:00',
      taken: false,
    ),
  ];

  static const _testUser = AppUser(
    id: 1,
    email: 'roberto@uleammed.test',
    fullName: 'Roberto Andrade',
    isActive: true,
  );

  @override
  Future<AppSession?> restoreSession() async {
    currentSession = restoredSession;
    return restoredSession;
  }

  @override
  Future<AppSession> login({
    required String email,
    required String password,
  }) async {
    currentSession = const AppSession(
      apiUrl: 'http://localhost:8000',
      environment: 'test',
      user: _testUser,
    );
    return currentSession!;
  }

  @override
  Future<AppSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    currentSession = AppSession(
      apiUrl: 'http://localhost:8000',
      environment: 'test',
      user: AppUser(id: 2, email: email, fullName: fullName, isActive: true),
    );
    return currentSession!;
  }

  @override
  Future<AppSession> loadAppSession() async {
    return currentSession ??
        restoredSession ??
        const AppSession(
          apiUrl: 'http://localhost:8000',
          environment: 'test',
          user: _testUser,
        );
  }

  @override
  Future<AppSession> updateProfile({required String fullName}) async {
    final previous = await loadAppSession();
    currentSession = AppSession(
      apiUrl: previous.apiUrl,
      environment: previous.environment,
      user: AppUser(
        id: previous.user.id,
        email: previous.user.email,
        fullName: fullName,
        isActive: previous.user.isActive,
      ),
    );
    return currentSession!;
  }

  @override
  Future<String> requestPasswordReset({required String email}) async {
    return 'Si el correo existe, enviaremos instrucciones para restablecer la contrasena.';
  }

  @override
  Future<String> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return 'Contrasena actualizada correctamente.';
  }

  @override
  Future<void> logout() async {
    currentSession = null;
    restoredSession = null;
    didLogout = true;
  }

  @override
  Future<MedicalProfile> loadMedicalProfile() async {
    return medicalProfile;
  }

  @override
  Future<MedicalProfile> saveMedicalProfile(MedicalProfile profile) async {
    medicalProfile = profile.copyWith(syncStatus: SyncStatus.pending);
    return medicalProfile;
  }

  @override
  Future<List<MedicationItem>> listMedications() async {
    return medications;
  }

  @override
  Future<MedicationItem> saveMedication(MedicationItem medication) async {
    final index = medications.indexWhere((item) => item.id == medication.id);
    if (index >= 0) {
      medications[index] = medication;
    } else {
      medications.add(medication);
    }
    return medication;
  }

  @override
  Future<void> deleteMedication(String medicationId) async {
    medications.removeWhere((item) => item.id == medicationId);
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    return recordMedicationStatus(medicationId, DoseStatus.taken);
  }

  @override
  Future<MedicationMarkResult> recordMedicationStatus(
    String medicationId,
    DoseStatus status,
  ) async {
    final index = medications.indexWhere((item) => item.id == medicationId);
    final original = medications[index];
    final updated = original.copyWith(taken: status == DoseStatus.taken);
    medications[index] = updated;
    confirmations.insert(
      0,
      DoseConfirmation(
        id: '$medicationId-${confirmations.length}',
        medicationId: medicationId,
        medicationName: updated.name,
        status: status,
        recordedAt: DateTime(2026, 7, 6, 8, 0),
      ),
    );
    return MedicationMarkResult(
      medication: updated,
      takenCount: medications.where((item) => item.taken).length,
      totalCount: medications.length,
    );
  }

  @override
  Future<List<DoseConfirmation>> listDoseConfirmations() async {
    return confirmations;
  }

  final List<Appointment> appointments = [
    const Appointment(
      id: 'local-test',
      doctor: 'Dra. Demo',
      specialty: 'General',
      date: '06 Jul 2026',
      time: '10:00',
      location: 'Centro medico',
    ),
  ];

  @override
  Future<List<Appointment>> listAppointments() async {
    return appointments;
  }

  @override
  Future<Appointment> saveAppointment(Appointment appointment) async {
    final index = appointments.indexWhere((a) => a.id == appointment.id);
    if (index >= 0) {
      appointments[index] = appointment;
    } else {
      appointments.add(appointment);
    }
    return appointment;
  }

  @override
  Future<void> deleteAppointment(String appointmentId) async {
    appointments.removeWhere((a) => a.id == appointmentId);
  }

  final List<EmergencyContact> emergencyContacts = [
    const EmergencyContact(
      id: '911',
      name: 'Emergencias',
      phone: '911',
      isPrimary: true,
    ),
  ];

  @override
  Future<List<EmergencyContact>> listEmergencyContacts() async {
    return emergencyContacts;
  }

  @override
  Future<EmergencyContact> saveEmergencyContact(
    EmergencyContact contact,
  ) async {
    final index = emergencyContacts.indexWhere((c) => c.id == contact.id);
    if (index >= 0) {
      emergencyContacts[index] = contact;
    } else {
      emergencyContacts.add(contact);
    }
    return contact;
  }

  @override
  Future<void> deleteEmergencyContact(String contactId) async {
    emergencyContacts.removeWhere((c) => c.id == contactId);
  }

  final List<HealthEntry> healthEntries = [];

  @override
  Future<List<HealthEntry>> listHealthEntries() async {
    return healthEntries;
  }

  @override
  Future<HealthEntry> saveHealthEntry(HealthEntry entry) async {
    final index = healthEntries.indexWhere((e) => e.id == entry.id);
    if (index >= 0) {
      healthEntries[index] = entry;
    } else {
      healthEntries.add(entry);
    }
    return entry;
  }

  @override
  Future<void> deleteHealthEntry(String entryId) async {
    healthEntries.removeWhere((e) => e.id == entryId);
  }

  final List<CaregiverPermission> caregivers = [];

  @override
  Future<List<CaregiverPermission>> listCaregivers() async {
    return caregivers;
  }

  @override
  Future<CaregiverPermission> saveCaregiver(
    CaregiverPermission caregiver,
  ) async {
    final index = caregivers.indexWhere((c) => c.id == caregiver.id);
    if (index >= 0) {
      caregivers[index] = caregiver;
    } else {
      caregivers.add(caregiver);
    }
    return caregiver;
  }

  @override
  Future<void> deleteCaregiver(String caregiverId) async {
    caregivers.removeWhere((c) => c.id == caregiverId);
  }

  @override
  Future<int> pendingSyncCount() async {
    return medicalProfile.syncStatus == SyncStatus.pending ? 1 : 0;
  }

  @override
  Future<SyncSummary> synchronizePendingChanges() async {
    return const SyncSummary(
      processed: 0,
      pending: 0,
      message: 'Todo esta sincronizado.',
    );
  }
}

void main() {
  testWidgets('shows login when there is no stored session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(api: _FakeApi(), settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('authenticates and loads home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(api: _FakeApi(), settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();

    await _loginWithForm(tester);

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Medicamentos'), findsWidgets);
  });

  testWidgets('restores stored session on app start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(
        api: _FakeApi(
          restoredSession: const AppSession(
            apiUrl: 'http://localhost:8000',
            environment: 'test',
            user: _FakeApi._testUser,
          ),
        ),
        settingsController: _testSettings(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('logout returns to login screen', (WidgetTester tester) async {
    final api = _FakeApi();

    await tester.pumpWidget(
      UleamMedApp(api: api, settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();
    await _loginWithForm(tester);
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(api.didLogout, isTrue);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('profile screen shows and updates user name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(api: _FakeApi(), settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();
    await _loginWithForm(tester);

    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('roberto@uleammed.test'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Roberto Nuevo',
    );
    await tester.tap(find.byTooltip('Guardar perfil medico'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil medico guardado'), findsOneWidget);
    expect(find.text('Roberto Nuevo'), findsWidgets);
  });

  testWidgets('home shows upcoming doses and marks one as taken', (
    WidgetTester tester,
  ) async {
    final api = _FakeApi();

    await tester.pumpWidget(
      UleamMedApp(api: api, settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();
    await _loginWithForm(tester);

    expect(find.text('Proximas tomas'), findsOneWidget);
    expect(find.text('Omeprazol - 20 mg'), findsOneWidget);

    final takenButton = find.widgetWithText(FilledButton, 'Tomado');
    await tester.ensureVisible(takenButton);
    await tester.pumpAndSettle();
    await tester.tap(takenButton);
    await tester.pumpAndSettle();

    expect(find.text('Omeprazol: marcado como tomado'), findsOneWidget);
    expect(
      api.confirmations.any(
        (c) => c.medicationId == 'omeprazol' && c.status == DoseStatus.taken,
      ),
      isTrue,
    );
  });

  testWidgets('password recovery requests code and resets password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(api: _FakeApi(), settingsController: _testSettings()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Olvide mi contrasena'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electronico'),
      'roberto@uleammed.test',
    );
    await tester.tap(find.text('Solicitar codigo'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Si el correo existe, enviaremos instrucciones para restablecer la contrasena.',
      ),
      findsOneWidget,
    );
    expect(find.text('Codigo de 6 digitos'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Codigo de 6 digitos'),
      '123456',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contrasena'),
      'nueva-clave-123',
    );
    final resetButton = find.text(
      'Restablecer contrasena',
      skipOffstage: false,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
