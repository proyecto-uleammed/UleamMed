import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_states.dart';
import '../history_screen.dart';
import '../medication_trash_screen.dart';
import '../medications_screen.dart';

class CaregiverPatientMedicationsScreen extends StatefulWidget {
  const CaregiverPatientMedicationsScreen({
    super.key,
    required this.api,
    required this.patient,
  });

  final UleamMedApi api;
  final CaregiverPatient patient;

  @override
  State<CaregiverPatientMedicationsScreen> createState() =>
      _CaregiverPatientMedicationsScreenState();
}

class _CaregiverPatientMedicationsScreenState
    extends State<CaregiverPatientMedicationsScreen> {
  late Future<List<MedicationItem>> _medications = widget.api
      .listCaregiverPatientMedications(widget.patient.id);
  final Set<String> _busyIds = {};

  Future<void> _refresh() async {
    setState(() {
      _medications = widget.api.listCaregiverPatientMedications(
        widget.patient.id,
      );
    });
    await _medications;
  }

  Future<void> _openMedicationForm([MedicationItem? medication]) async {
    final saved = await showMedicationEditorSheet(
      context,
      medication: medication,
      onSave: (item) =>
          widget.api.saveCaregiverPatientMedication(widget.patient.id, item),
      onDelete: medication == null
          ? null
          : () => widget.api.deleteCaregiverPatientMedication(
              widget.patient.id,
              medication.id,
            ),
    );

    if (saved == true && mounted) {
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        medication == null
            ? 'Medicamento agregado para ${widget.patient.fullName}'
            : 'Medicamento actualizado',
      );
    }
  }

  Future<void> _toggleTaken(MedicationItem medication) async {
    if (_busyIds.contains(medication.id)) {
      return;
    }

    setState(() => _busyIds.add(medication.id));

    try {
      if (!medication.taken) {
        await widget.api.recordCaregiverPatientDoseEvent(
          patientId: widget.patient.id,
          medicationId: medication.id,
          status: DoseStatus.taken,
          scheduledAt: DateTime.now(),
          sequenceNumber: 1,
        );
      } else {
        await widget.api.saveCaregiverPatientMedication(
          widget.patient.id,
          medication.copyWith(taken: false),
        );
      }
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        medication.taken
            ? '${medication.name} marcado como pendiente'
            : '${medication.name} marcado como tomado',
      );
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(medication.id));
      }
    }
  }

  Future<void> _deleteMedication(MedicationItem medication) async {
    if (_busyIds.contains(medication.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: Text(
          'Se eliminará ${medication.name} del perfil de ${widget.patient.fullName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _busyIds.add(medication.id));

    try {
      await widget.api.deleteCaregiverPatientMedication(
        widget.patient.id,
        medication.id,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      showAppSnackBar(context, '${medication.name} eliminado');
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(medication.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patient.fullName),
        actions: [
          IconButton(
            tooltip: 'Papelera',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => MedicationTrashScreen(
                    api: widget.api,
                    patientId: widget.patient.id,
                    title: 'Papelera de ${widget.patient.fullName}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Historial de tomas',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => HistoryScreen(
                    api: widget.api,
                    patientId: widget.patient.id,
                    title: 'Historial de ${widget.patient.fullName}',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-patient-medication',
        onPressed: () => _openMedicationForm(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder<List<MedicationItem>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(),
            );
          }
          final medications = snapshot.data ?? const [];
          if (medications.isEmpty) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const EmptyStateView(
                icon: Icons.medication_outlined,
                title: 'Sin medicamentos',
                message:
                    'Agrega el primer medicamento para que el paciente lo vea en su panel.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: medications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final medication = medications[index];
                return _CaregiverMedicationCard(
                  medication: medication,
                  busy: _busyIds.contains(medication.id),
                  onEdit: () => _openMedicationForm(medication),
                  onToggleTaken: () => _toggleTaken(medication),
                  onDelete: () => _deleteMedication(medication),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CaregiverMedicationCard extends StatelessWidget {
  const _CaregiverMedicationCard({
    required this.medication,
    required this.busy,
    required this.onEdit,
    required this.onToggleTaken,
    required this.onDelete,
  });

  final MedicationItem medication;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleTaken;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CaregiverMedicationAvatar(medication: medication),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medication.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(
                              medication.taken ? 'Tomado' : 'Pendiente',
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${medication.dose} · ${medication.time}'),
                      Text(medication.frequency),
                      if (medication.instructions.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          medication.instructions,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onToggleTaken,
                  icon: Icon(
                    medication.taken
                        ? Icons.radio_button_unchecked
                        : Icons.check_circle_outline,
                  ),
                  label: Text(
                    medication.taken ? 'Marcar pendiente' : 'Marcar tomado',
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                TextButton.icon(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CaregiverMedicationAvatar extends StatelessWidget {
  const _CaregiverMedicationAvatar({required this.medication});

  final MedicationItem medication;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        medication.photoPath.isNotEmpty &&
        File(medication.photoPath).existsSync();
    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.file(
          File(medication.photoPath),
          key: ValueKey(medication.photoPath),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _CaregiverMedicationAvatarFallback(taken: medication.taken),
        ),
      );
    }
    return _CaregiverMedicationAvatarFallback(taken: medication.taken);
  }
}

class _CaregiverMedicationAvatarFallback extends StatelessWidget {
  const _CaregiverMedicationAvatarFallback({required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: AppColors.accent.withValues(alpha: 0.35),
      child: Icon(
        taken ? Icons.check : Icons.medication,
        color: AppColors.primaryDark,
      ),
    );
  }
}
