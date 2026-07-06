import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Proximas tomas accionables en el inicio (tomado/posponer/omitir) (PB-023).
class UpcomingDoses extends StatefulWidget {
  const UpcomingDoses({super.key, required this.api, this.onChanged});

  final UleamMedApi api;
  final VoidCallback? onChanged;

  @override
  State<UpcomingDoses> createState() => _UpcomingDosesState();
}

class _UpcomingDosesState extends State<UpcomingDoses> {
  late Future<List<MedicationItem>> _future = widget.api.listMedications();
  bool _working = false;

  void _reload() {
    setState(() {
      _future = widget.api.listMedications();
    });
    widget.onChanged?.call();
  }

  int _minutesOf(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      return 24 * 60;
    }
    final hour = int.tryParse(parts[0]) ?? 24;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  Future<void> _record(MedicationItem med, DoseStatus status) async {
    setState(() => _working = true);
    try {
      await widget.api.recordMedicationStatus(med.id, status);
    } catch (_) {
      // Se guarda localmente; si falla se ignora en la vista de inicio.
    }
    if (!mounted) {
      return;
    }
    setState(() => _working = false);
    final message = switch (status) {
      DoseStatus.taken => '${med.name}: marcado como tomado',
      DoseStatus.omitted => '${med.name}: marcado como omitido',
      DoseStatus.postponed => '${med.name}: pospuesto',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
    _reload();
  }

  Future<void> _postpone(MedicationItem med) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Posponer recordatorio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            ...[10, 15, 30, 60].map(
              (m) => ListTile(
                leading: const Icon(Icons.snooze),
                title: Text('$m minutos'),
                onTap: () => Navigator.pop(context, m),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (minutes == null || !mounted) {
      return;
    }
    await _record(med, DoseStatus.postponed);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedicationItem>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final meds = snapshot.data ?? const [];
        final pending =
            meds.where((m) => !m.taken).toList()
              ..sort((a, b) => _minutesOf(a.time).compareTo(_minutesOf(b.time)));
        final next = pending.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Proximas tomas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (meds.isEmpty)
              _EmptyDosesHint(
                icon: Icons.medication_outlined,
                title: 'Aun no tienes medicamentos',
                message:
                    'Cuando agregues tus medicamentos en la pestana Medicinas, '
                    'aqui veras las proximas tomas del dia con botones para '
                    'marcarlas como tomadas, posponerlas u omitirlas.',
              )
            else if (next.isEmpty)
              _EmptyDosesHint(
                icon: Icons.check_circle_outline,
                title: 'Tomas al dia',
                message:
                    'No tienes tomas pendientes por ahora. Cuando llegue la '
                    'hora de tu siguiente medicamento, aparecera aqui.',
              )
            else
              ...next.map((med) => _DoseCard(
                    med: med,
                    enabled: !_working,
                    onTaken: () => _record(med, DoseStatus.taken),
                    onPostpone: () => _postpone(med),
                    onOmit: () => _record(med, DoseStatus.omitted),
                  )),
          ],
        );
      },
    );
  }
}

class _EmptyDosesHint extends StatelessWidget {
  const _EmptyDosesHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.med,
    required this.enabled,
    required this.onTaken,
    required this.onPostpone,
    required this.onOmit,
  });

  final MedicationItem med;
  final bool enabled;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;
  final VoidCallback onOmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${med.name} - ${med.dose}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'A las ${med.time}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled ? onTaken : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tomado'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Posponer',
                  onPressed: enabled ? onPostpone : null,
                  icon: const Icon(Icons.snooze),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  tooltip: 'Omitir',
                  onPressed: enabled ? onOmit : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
