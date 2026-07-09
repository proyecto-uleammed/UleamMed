import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/app_states.dart';

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

  void _reload() {
    setState(() {
      _medications = widget.api.listCaregiverPatientMedications(
        widget.patient.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patient.fullName)),
      body: FutureBuilder<List<MedicationItem>>(
        future: _medications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }
          final medications = snapshot.data ?? const [];
          if (medications.isEmpty) {
            return const EmptyStateView(
              icon: Icons.medication_outlined,
              title: 'Sin medicamentos',
              message: 'Este paciente no tiene medicamentos registrados.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: medications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _ReadOnlyMedicationCard(medication: medications[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ReadOnlyMedicationCard extends StatelessWidget {
  const _ReadOnlyMedicationCard({required this.medication});

  final MedicationItem medication;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          child: Icon(medication.taken ? Icons.check : Icons.medication),
        ),
        title: Text(
          medication.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${medication.dose} · ${medication.time}\n${medication.frequency}',
        ),
        isThreeLine: true,
        trailing: Chip(label: Text(medication.taken ? 'Tomado' : 'Pendiente')),
      ),
    );
  }
}
