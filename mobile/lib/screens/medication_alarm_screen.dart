import 'dart:io';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/medication_schedule_service.dart';
import '../services/notification_scheduler.dart';
import '../theme/app_theme.dart';

class MedicationAlarmScreen extends StatefulWidget {
  const MedicationAlarmScreen({
    super.key,
    required this.alarmId,
    required this.occurrences,
    required this.api,
    required this.scheduler,
  });

  final int alarmId;
  final List<MedicationOccurrence> occurrences;
  final UleamMedApi api;
  final NotificationScheduler scheduler;

  @override
  State<MedicationAlarmScreen> createState() => _MedicationAlarmScreenState();
}

class _MedicationAlarmScreenState extends State<MedicationAlarmScreen> {
  final _scheduleService = const MedicationScheduleService();
  int _index = 0;
  bool _saving = false;

  MedicationOccurrence get _current => widget.occurrences[_index];

  Future<void> _record(DoseStatus status, {Duration? snooze}) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    final snoozedUntil = snooze == null ? null : DateTime.now().add(snooze);
    try {
      await widget.api.recordScheduledDose(
        medicationId: _current.medication.id,
        status: status,
        scheduledAt: _current.scheduledAt,
        sequenceNumber: _current.sequenceNumber,
        snoozedUntil: snoozedUntil,
      );
      if (snooze != null) {
        await widget.scheduler.snooze(_current, snooze);
      }
      if (_index + 1 < widget.occurrences.length) {
        if (mounted) {
          setState(() {
            _index++;
            _saving = false;
          });
        }
        return;
      }
      await widget.scheduler.stopAlarm(widget.alarmId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _chooseSnooze() async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.snooze),
              title: Text('¿Cuánto tiempo deseas posponer?'),
            ),
            for (final value in const [10, 15, 30, 60])
              ListTile(
                title: Text('$value minutos'),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
    if (minutes != null) {
      await _record(DoseStatus.postponed, snooze: Duration(minutes: minutes));
    }
  }

  @override
  Widget build(BuildContext context) {
    final medication = _current.medication;
    final dailyCount = _scheduleService
        .occurrencesForDay(medication, _current.scheduledAt)
        .length;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.alarm_on, size: 64, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                'Hora de tu medicamento',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              _MedicationPhoto(path: medication.photoPath),
              const SizedBox(height: 20),
              Text(
                medication.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                medication.dose,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 10),
              Text(
                'Toma ${_current.sequenceNumber} de '
                '${dailyCount == 0 ? 1 : dailyCount} de hoy',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (medication.instructions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    medication.instructions,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
              if (widget.occurrences.length > 1) ...[
                const SizedBox(height: 12),
                Text(
                  '${_index + 1} de ${widget.occurrences.length} medicamentos',
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: _saving ? null : () => _record(DoseStatus.taken),
                icon: const Icon(Icons.check_circle),
                label: const Text('Tomado'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _chooseSnooze,
                icon: const Icon(Icons.snooze),
                label: const Text('Posponer'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _record(DoseStatus.omitted),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Omitir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationPhoto extends StatelessWidget {
  const _MedicationPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (path.isNotEmpty && file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          file,
          height: 230,
          width: double.infinity,
          fit: BoxFit.contain,
        ),
      );
    }
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.medication, size: 92, color: AppColors.primary),
    );
  }
}
