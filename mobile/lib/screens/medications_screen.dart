import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  static const _medications = [
  _Medication(
    name: 'Metformina',
    dose: '500 mg',
    time: '08:00',
    taken: true,
  ),
  _Medication(
    name: 'Losartán',
    dose: '50 mg',
    time: '08:00',
    taken: true,
  ),
  _Medication(
    name: 'Omeprazol',
    dose: '20 mg',
    time: '14:00',
    taken: false,
  ),
  _Medication(
    name: 'Atorvastatina',
    dose: '10 mg',
    time: '20:00',
    taken: false,
  ),
];

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Medicamentos')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hoy tienes 4 medicamentos programados. 2 ya tomados.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._medications.map((med) => _MedicationCard(medication: med)),
      ],
    ),
  );
  }
}

class _Medication {
  const _Medication({
    required this.name,
    required this.dose,
    required this.time,
    required this.taken,
  });

  final String name;
  final String dose;
  final String time;
  final bool taken;
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.medication});

  final _Medication medication;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: medication.taken
                    ? AppColors.primaryLight.withValues(alpha: 0.2)
                    : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                medication.taken ? Icons.check_circle : Icons.medication,
                color: medication.taken
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(medication.name, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${medication.dose} · ${medication.time}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            if (medication.taken)
              const Chip(
                label: Text('Tomado', style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.primary,
              )
            else
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Marcar'),
              ),
          ],
        ),
      ),
    );
  }
}
