import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uleam_med/main.dart';
import 'package:uleam_med/services/api_service.dart';

class _FakeApi implements UleamMedApi {
  _FakeApi({this.restoredSession});

  DemoSession? restoredSession;
  DemoSession? currentSession;
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

  static const _demoUser = DemoUser(
    id: 1,
    email: 'roberto@uleammed.demo',
    fullName: 'Roberto Andrade',
    isActive: true,
  );

  @override
  Future<DemoSession?> restoreSession() async {
    currentSession = restoredSession;
    return restoredSession;
  }

  @override
  Future<DemoSession> login({
    required String email,
    required String password,
  }) async {
    currentSession = const DemoSession(
      apiUrl: 'http://localhost:8000',
      environment: 'test',
      user: _demoUser,
    );
    return currentSession!;
  }

  @override
  Future<DemoSession> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    currentSession = DemoSession(
      apiUrl: 'http://localhost:8000',
      environment: 'test',
      user: DemoUser(id: 2, email: email, fullName: fullName, isActive: true),
    );
    return currentSession!;
  }

  @override
  Future<DemoSession> startDemoSession() async {
    return login(email: _demoUser.email, password: 'clave-segura-123');
  }

  @override
  Future<DemoSession> loadDemoSession() async {
    return currentSession ??
        restoredSession ??
        const DemoSession(
          apiUrl: 'http://localhost:8000',
          environment: 'test',
          user: _demoUser,
        );
  }

  @override
  Future<DemoSession> updateProfile({required String fullName}) async {
    final previous = await loadDemoSession();
    currentSession = DemoSession(
      apiUrl: previous.apiUrl,
      environment: previous.environment,
      user: DemoUser(
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

  @override
  Future<List<Appointment>> listAppointments() async {
    return const [
      Appointment(
        id: 'demo',
        doctor: 'Dra. Demo',
        specialty: 'General',
        date: '06 Jul 2026',
        time: '10:00',
        location: 'Centro medico',
      ),
    ];
  }

  @override
  Future<List<EmergencyContact>> listEmergencyContacts() async {
    return const [
      EmergencyContact(
        id: '911',
        name: 'Emergencias',
        phone: '911',
        isPrimary: true,
      ),
    ];
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
    await tester.pumpWidget(UleamMedApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Entrar en modo demo'), findsOneWidget);
  });

  testWidgets('authenticates and loads home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(UleamMedApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Entrar en modo demo'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Backend conectado'), findsOneWidget);
    expect(find.text('Medicamentos'), findsWidgets);
  });

  testWidgets('restores stored session on app start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      UleamMedApp(
        api: _FakeApi(
          restoredSession: const DemoSession(
            apiUrl: 'http://localhost:8000',
            environment: 'test',
            user: _FakeApi._demoUser,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);
  });

  testWidgets('logout returns to login screen', (WidgetTester tester) async {
    final api = _FakeApi();

    await tester.pumpWidget(UleamMedApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar en modo demo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(api.didLogout, isTrue);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('profile screen shows and updates user name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(UleamMedApp(api: _FakeApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrar en modo demo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.account_circle));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('roberto@uleammed.demo'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'),
      'Roberto Nuevo',
    );
    await tester.scrollUntilVisible(
      find.text('Guardar perfil medico'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Guardar perfil medico'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil medico guardado sin conexion'), findsOneWidget);
    expect(find.text('Roberto Nuevo'), findsWidgets);
  });

  testWidgets('password recovery requests code and resets password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(UleamMedApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Olvide mi contrasena'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electronico'),
      'roberto@uleammed.demo',
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
