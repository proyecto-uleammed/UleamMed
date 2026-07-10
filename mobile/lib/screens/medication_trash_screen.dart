import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_states.dart';

class MedicationTrashScreen extends StatefulWidget {
  const MedicationTrashScreen({
    super.key,
    required this.api,
    this.patientId,
    this.title = 'Papelera de medicamentos',
  });

  final UleamMedApi api;
  final int? patientId;
  final String title;

  @override
  State<MedicationTrashScreen> createState() => _MedicationTrashScreenState();
}

class _MedicationTrashScreenState extends State<MedicationTrashScreen> {
  late Future<List<MedicationItem>> _medications = _load();
  final Set<String> _busyIds = {};

  Future<List<MedicationItem>> _load() {
    final patientId = widget.patientId;
    if (patientId != null) {
      return widget.api.listCaregiverPatientDeletedMedications(patientId);
    }
    return widget.api.listDeletedMedications();
  }

  void _reload() {
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _medications = _load();
    });
    await _medications;
  }

  Future<void> _restore(MedicationItem medication) async {
    if (_busyIds.contains(medication.id)) {
      return;
    }
    setState(() => _busyIds.add(medication.id));
    try {
      if (widget.patientId != null) {
        await widget.api.restoreCaregiverPatientMedication(
          widget.patientId!,
          medication.id,
        );
      } else {
        await widget.api.restoreMedication(medication.id);
      }
      if (!mounted) {
        return;
      }
      _reload();
      showAppSnackBar(context, '${medication.name} restaurado');
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
        title: Text(widget.title),
      ),
      body: FutureBuilder<List<MedicationItem>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Cargando papelera...');
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }
          final medications = snapshot.data ?? const [];
          if (medications.isEmpty) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const EmptyStateView(
                icon: Icons.delete_outline,
                title: 'Papelera vacia',
                message:
                    'Los medicamentos eliminados apareceran aqui para poder restaurarlos.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: medications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final medication = medications[index];
              final busy = _busyIds.contains(medication.id);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.medication_outlined),
                  ),
                  title: Text(medication.name),
                  subtitle: Text('${medication.dose} · ${medication.time}'),
                  trailing: FilledButton.tonalIcon(
                    onPressed: busy ? null : () => _restore(medication),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore),
                    label: const Text('Restaurar'),
                  ),
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }
}
