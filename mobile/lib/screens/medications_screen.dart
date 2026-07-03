import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<MedicationItem>> _medications = _api.listMedications();
  final Set<String> _savingIds = {};

  void _reload() {
    setState(() {
      _medications = _api.listMedications();
    });
  }

  Future<void> _markAsTaken(MedicationItem medication) async {
    if (medication.taken || _savingIds.contains(medication.id)) {
      return;
    }

    setState(() {
      _savingIds.add(medication.id);
    });

    try {
      final result = await _api.markMedicationTaken(medication.id);
      if (!mounted) {
        return;
      }

      setState(() {
        _medications = _medications.then((items) {
          return items.map((item) {
            if (item.id == result.medication.id) {
              return result.medication;
            }
            return item;
          }).toList();
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.medication.name} marcado como tomado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo marcar el medicamento'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingIds.remove(medication.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos')),
      body: FutureBuilder<List<MedicationItem>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MedicationError(onRetry: _reload);
          }

          final medications = snapshot.data ?? [];
          final takenCount = medications
              .where((medication) => medication.taken)
              .length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MedicationSummary(
                totalCount: medications.length,
                takenCount: takenCount,
              ),
              const SizedBox(height: 16),
              ...medications.map(
                (medication) => _MedicationCard(
                  medication: medication,
                  isSaving: _savingIds.contains(medication.id),
                  onMark: () => _markAsTaken(medication),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MedicationSummary extends StatelessWidget {
  const _MedicationSummary({
    required this.totalCount,
    required this.takenCount,
  });

  final int totalCount;
  final int takenCount;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Hoy tienes $totalCount medicamentos programados. $takenCount ya tomados.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationError extends StatelessWidget {
  const _MedicationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar los medicamentos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Revisa que el backend este levantado y vuelve a intentar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.isSaving,
    required this.onMark,
  });

  final MedicationItem medication;
  final bool isSaving;
  final VoidCallback onMark;

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
                  Text(
                    medication.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
              SizedBox(
                width: 116,
                child: OutlinedButton(
                  onPressed: isSaving ? null : onMark,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Marcar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
