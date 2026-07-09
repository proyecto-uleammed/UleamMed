import '../models/local_models.dart';

class MedicationOccurrence {
  const MedicationOccurrence({
    required this.medication,
    required this.scheduledAt,
    required this.sequenceNumber,
  });

  final MedicationItem medication;
  final DateTime scheduledAt;
  final int sequenceNumber;

  String get eventId =>
      '${medication.id}-${scheduledAt.toUtc().millisecondsSinceEpoch}';
}

class MedicationScheduleService {
  const MedicationScheduleService();

  MedicationOccurrence? nextOccurrence(
    MedicationItem medication, {
    DateTime? after,
  }) {
    final reference = after ?? DateTime.now();
    final schedule = medication.effectiveSchedule;
    final start = DateTime(
      schedule.startDate.year,
      schedule.startDate.month,
      schedule.startDate.day,
    );
    final end = schedule.endDate == null
        ? reference.add(const Duration(days: 370))
        : DateTime(
            schedule.endDate!.year,
            schedule.endDate!.month,
            schedule.endDate!.day,
            23,
            59,
            59,
          );
    if (reference.isAfter(end)) {
      return null;
    }

    if (schedule.mode == MedicationScheduleMode.interval) {
      return _nextInterval(medication, schedule, reference, start, end);
    }
    return _nextFixed(medication, schedule, reference, start, end);
  }

  List<MedicationOccurrence> occurrencesForDay(
    MedicationItem medication,
    DateTime day,
  ) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final result = <MedicationOccurrence>[];
    var cursor = start.subtract(const Duration(milliseconds: 1));
    while (true) {
      final next = nextOccurrence(medication, after: cursor);
      if (next == null || !next.scheduledAt.isBefore(end)) {
        break;
      }
      if (!next.scheduledAt.isBefore(start)) {
        result.add(next);
      }
      cursor = next.scheduledAt;
    }
    return result;
  }

  MedicationOccurrence? _nextFixed(
    MedicationItem medication,
    MedicationSchedule schedule,
    DateTime reference,
    DateTime start,
    DateTime end,
  ) {
    final times =
        schedule.times.map(_parseTime).whereType<_ClockTime>().toList()
          ..sort((a, b) => a.minutes.compareTo(b.minutes));
    var day = DateTime(reference.year, reference.month, reference.day);
    if (day.isBefore(start)) {
      day = start;
    }
    while (!day.isAfter(end)) {
      if (schedule.weekdays.contains(day.weekday)) {
        for (var index = 0; index < times.length; index++) {
          final value = times[index];
          final candidate = DateTime(
            day.year,
            day.month,
            day.day,
            value.hour,
            value.minute,
          );
          if (candidate.isAfter(reference) &&
              !candidate.isBefore(start) &&
              !candidate.isAfter(end)) {
            return MedicationOccurrence(
              medication: medication,
              scheduledAt: candidate,
              sequenceNumber: index + 1,
            );
          }
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return null;
  }

  MedicationOccurrence? _nextInterval(
    MedicationItem medication,
    MedicationSchedule schedule,
    DateTime reference,
    DateTime start,
    DateTime end,
  ) {
    final anchorClock = schedule.times.isEmpty
        ? null
        : _parseTime(schedule.times.first);
    final interval = schedule.intervalHours;
    if (anchorClock == null || interval == null) {
      return null;
    }
    final anchor = DateTime(
      start.year,
      start.month,
      start.day,
      anchorClock.hour,
      anchorClock.minute,
    );
    var candidate = anchor;
    if (!candidate.isAfter(reference)) {
      final elapsed = reference.difference(anchor).inMinutes;
      final intervalMinutes = interval * 60;
      final jumps = (elapsed ~/ intervalMinutes) + 1;
      candidate = anchor.add(Duration(minutes: jumps * intervalMinutes));
    }
    while (!candidate.isAfter(end)) {
      if (schedule.weekdays.contains(candidate.weekday)) {
        final dayOccurrences = _intervalSequenceForDay(
          anchor,
          interval,
          candidate,
        );
        return MedicationOccurrence(
          medication: medication,
          scheduledAt: candidate,
          sequenceNumber: dayOccurrences,
        );
      }
      candidate = candidate.add(Duration(hours: interval));
    }
    return null;
  }

  int _intervalSequenceForDay(
    DateTime anchor,
    int intervalHours,
    DateTime candidate,
  ) {
    var count = 1;
    var cursor = candidate.subtract(Duration(hours: intervalHours));
    while (!cursor.isBefore(anchor) &&
        cursor.year == candidate.year &&
        cursor.month == candidate.month &&
        cursor.day == candidate.day) {
      count++;
      cursor = cursor.subtract(Duration(hours: intervalHours));
    }
    return count;
  }

  _ClockTime? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return _ClockTime(hour, minute);
  }
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;
  int get minutes => hour * 60 + minute;
}
