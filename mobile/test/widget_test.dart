import 'package:flutter_test/flutter_test.dart';

import 'package:uleam_med/main.dart';
import 'package:uleam_med/services/api_service.dart';

class _FakeApi implements UleamMedApi {
  @override
  Future<DemoSession> loadDemoSession() async {
    return const DemoSession(
      apiUrl: 'http://localhost:8000',
      environment: 'test',
      user: DemoUser(
        id: 1,
        email: 'roberto@uleammed.demo',
        fullName: 'Roberto Andrade',
        isActive: true,
      ),
    );
  }

  @override
  Future<List<MedicationItem>> listMedications() async {
    return const [
      MedicationItem(
        id: 'metformina',
        name: 'Metformina',
        dose: '500 mg',
        time: '08:00',
        taken: true,
      ),
      MedicationItem(
        id: 'omeprazol',
        name: 'Omeprazol',
        dose: '20 mg',
        time: '14:00',
        taken: false,
      ),
    ];
  }

  @override
  Future<MedicationMarkResult> markMedicationTaken(String medicationId) async {
    return const MedicationMarkResult(
      medication: MedicationItem(
        id: 'omeprazol',
        name: 'Omeprazol',
        dose: '20 mg',
        time: '14:00',
        taken: true,
      ),
      takenCount: 2,
      totalCount: 2,
    );
  }
}

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(UleamMedApp(api: _FakeApi()));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Roberto 👋'), findsOneWidget);
    expect(find.text('Backend conectado'), findsOneWidget);
    expect(find.text('Medicamentos'), findsWidgets);
  });
}
