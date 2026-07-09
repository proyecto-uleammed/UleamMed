import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';

import '../models/local_models.dart';
import 'medication_schedule_service.dart';

typedef AlarmRingingCallback =
    void Function(int alarmId, List<MedicationOccurrence> occurrences);

class NotificationScheduler {
  NotificationScheduler({
    this._scheduleService = const MedicationScheduleService(),
  });

  final MedicationScheduleService _scheduleService;
  StreamSubscription<dynamic>? _ringingSubscription;
  AlarmRingingCallback? _onAlarmRinging;
  final Set<int> _handledRinging = {};
  bool _initialized = false;

  Future<bool> initialize({
    VoidCallback? onOpenMedications,
    AlarmRingingCallback? onAlarmRinging,
  }) async {
    _onAlarmRinging = onAlarmRinging;
    if (_initialized) {
      return Alarm.ringing.value.alarms.isNotEmpty;
    }
    _ringingSubscription = Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        if (_handledRinging.add(alarm.id)) {
          final occurrences = _decodeOccurrences(alarm.payload);
          if (occurrences.isNotEmpty) {
            _scheduleFollowingOccurrences(occurrences);
            _onAlarmRinging?.call(alarm.id, occurrences);
          } else {
            onOpenMedications?.call();
          }
        }
      }
      _handledRinging.removeWhere(
        (id) => !alarmSet.alarms.any((alarm) => alarm.id == id),
      );
    });
    _initialized = true;

    final ringing = Alarm.ringing.value.alarms;
    if (ringing.isEmpty) {
      return false;
    }
    for (final alarm in ringing) {
      if (_handledRinging.add(alarm.id)) {
        final occurrences = _decodeOccurrences(alarm.payload);
        if (occurrences.isNotEmpty) {
          _onAlarmRinging?.call(alarm.id, occurrences);
        }
      }
    }
    return true;
  }

  Future<void> reconcile(List<MedicationItem> medications) async {
    await _cancelScheduledAlarms();
    final occurrences = medications
        .map((medication) => _scheduleService.nextOccurrence(medication))
        .whereType<MedicationOccurrence>()
        .toList();
    await _scheduleGrouped(occurrences);
  }

  Future<void> _cancelScheduledAlarms() async {
    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      if (!await Alarm.isRinging(alarm.id)) {
        await Alarm.stop(alarm.id);
      }
    }
  }

  Future<void> schedule(MedicationItem medication) async {
    await cancel(medication.id);
    final occurrence = _scheduleService.nextOccurrence(medication);
    if (occurrence != null) {
      await _setAlarm([occurrence]);
    }
  }

  Future<void> cancel(String medicationId) async {
    final alarms = await Alarm.getAlarms();
    for (final alarm in alarms) {
      final occurrences = _decodeOccurrences(alarm.payload);
      if (occurrences.any(
        (occurrence) => occurrence.medication.id == medicationId,
      )) {
        await Alarm.stop(alarm.id);
      }
    }
  }

  Future<void> cancelAll() => Alarm.stopAll();

  Future<void> stopAlarm(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  Future<void> snooze(
    MedicationOccurrence occurrence,
    Duration duration,
  ) async {
    final postponed = MedicationOccurrence(
      medication: occurrence.medication,
      scheduledAt: DateTime.now().add(duration),
      sequenceNumber: occurrence.sequenceNumber,
    );
    await _setAlarm([postponed], isSnooze: true);
  }

  Future<void> _scheduleFollowingOccurrences(
    List<MedicationOccurrence> current,
  ) async {
    final next = current
        .map(
          (occurrence) => _scheduleService.nextOccurrence(
            occurrence.medication,
            after: occurrence.scheduledAt,
          ),
        )
        .whereType<MedicationOccurrence>()
        .toList();
    await _scheduleGrouped(next);
  }

  Future<void> _scheduleGrouped(List<MedicationOccurrence> occurrences) async {
    final groups = <String, List<MedicationOccurrence>>{};
    for (final occurrence in occurrences) {
      final date = occurrence.scheduledAt;
      final key =
          '${date.year}-${date.month}-${date.day}-${date.hour}-${date.minute}';
      groups.putIfAbsent(key, () => []).add(occurrence);
    }
    for (final group in groups.values) {
      await _setAlarm(group);
    }
  }

  Future<void> _setAlarm(
    List<MedicationOccurrence> occurrences, {
    bool isSnooze = false,
  }) async {
    if (occurrences.isEmpty) {
      return;
    }
    final when = occurrences.first.scheduledAt;
    final names = occurrences.map((item) => item.medication.name).join(', ');
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: _alarmId(occurrences, isSnooze: isSnooze),
        dateTime: when,
        assetAudioPath: null,
        loopAudio: true,
        vibrate: true,
        warningNotificationOnKill: false,
        androidFullScreenIntent: true,
        androidStopAlarmOnTermination: false,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 10),
          volume: 0.8,
          volumeEnforced: true,
          showSystemUI: false,
        ),
        notificationSettings: NotificationSettings(
          title: 'Hora de tu medicamento',
          body: names,
        ),
        payload: jsonEncode(
          occurrences.map((item) => _occurrenceToJson(item)).toList(),
        ),
      ),
    );
  }

  Map<String, dynamic> _occurrenceToJson(MedicationOccurrence occurrence) {
    return {
      'medication': occurrence.medication.toJson(),
      'scheduledAt': occurrence.scheduledAt.toIso8601String(),
      'sequenceNumber': occurrence.sequenceNumber,
    };
  }

  List<MedicationOccurrence> _decodeOccurrences(String? payload) {
    if (payload == null || payload.isEmpty) {
      return [];
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! List) {
        return [];
      }
      return decoded.whereType<Map>().map((item) {
        final json = Map<String, dynamic>.from(item);
        return MedicationOccurrence(
          medication: MedicationItem.fromJson(
            Map<String, dynamic>.from(json['medication'] as Map),
          ),
          scheduledAt: DateTime.parse(json['scheduledAt'].toString()),
          sequenceNumber: (json['sequenceNumber'] as num?)?.toInt() ?? 1,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  int _alarmId(
    List<MedicationOccurrence> occurrences, {
    required bool isSnooze,
  }) {
    final medicationIds = occurrences.map((item) => item.medication.id).toList()
      ..sort();
    final value = [
      if (isSnooze) 'snooze',
      occurrences.first.scheduledAt.toUtc().millisecondsSinceEpoch.toString(),
      ...medicationIds,
    ].join(':');
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  List<String> reminderPreview(List<MedicationItem> medications) {
    return medications
        .map((medication) {
          final next = _scheduleService.nextOccurrence(medication);
          if (next == null) {
            return null;
          }
          final hour = next.scheduledAt.hour.toString().padLeft(2, '0');
          final minute = next.scheduledAt.minute.toString().padLeft(2, '0');
          return '$hour:$minute - ${medication.name}';
        })
        .whereType<String>()
        .toList();
  }

  Future<void> dispose() async {
    await _ringingSubscription?.cancel();
  }
}
