import 'package:flutter_test/flutter_test.dart';
import 'package:uleam_med/models/local_models.dart';
import 'package:uleam_med/services/medication_schedule_service.dart';

void main() {
  const service = MedicationScheduleService();

  MedicationItem medication(MedicationSchedule schedule) {
    return MedicationItem(
      id: '1',
      name: 'Medicamento',
      dose: '150 mg',
      time: schedule.times.first,
      taken: false,
      schedule: schedule,
    );
  }

  test('cada 12 horas genera dos tomas diarias', () {
    final item = medication(
      MedicationSchedule(
        mode: MedicationScheduleMode.interval,
        intervalHours: 12,
        times: const ['08:00'],
        weekdays: const [1, 2, 3, 4, 5, 6, 7],
        startDate: DateTime(2026, 7, 9),
      ),
    );

    final occurrences = service.occurrencesForDay(item, DateTime(2026, 7, 9));

    expect(occurrences.map((item) => item.scheduledAt.hour), [8, 20]);
    expect(occurrences.map((item) => item.sequenceNumber), [1, 2]);
  });

  test('respeta horas, dias seleccionados y fecha final', () {
    final item = medication(
      MedicationSchedule(
        mode: MedicationScheduleMode.fixedTimes,
        times: const ['07:30', '19:30'],
        weekdays: const [1],
        startDate: DateTime(2026, 7, 6),
        endDate: DateTime(2026, 7, 6),
      ),
    );

    expect(service.occurrencesForDay(item, DateTime(2026, 7, 6)).length, 2);
    expect(
      service.nextOccurrence(item, after: DateTime(2026, 7, 6, 20)),
      isNull,
    );
  });

  test('acepta doseAmount como texto decimal del backend', () {
    final item = MedicationItem.fromJson({
      'id': '10',
      'name': 'Metformina',
      'dose': '150 mg',
      'doseAmount': '150.00',
      'doseUnit': 'mg',
      'time': '08:00',
      'taken': false,
      'schedule': {
        'mode': 'fixed_times',
        'times': ['08:00'],
        'weekdays': [1, 2, 3, 4, 5, 6, 7],
        'start_date': '2026-07-09',
      },
    });

    expect(item.doseAmount, 150);
    expect(item.effectiveSchedule.times, ['08:00']);
  });
}
