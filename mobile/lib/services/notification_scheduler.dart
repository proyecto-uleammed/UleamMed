import '../models/local_models.dart';

class NotificationScheduler {
  const NotificationScheduler();

  Future<void> scheduleMedicationReminder(MedicationItem medication) async {
    // Flutter local notifications will be connected when the dependency is approved.
  }

  List<String> reminderPreview(List<MedicationItem> medications) {
    return medications
        .where((medication) => !medication.taken)
        .map((medication) => '${medication.time} - ${medication.name}')
        .toList();
  }
}
