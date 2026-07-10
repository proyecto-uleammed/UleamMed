import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../appointments_screen.dart';
import '../conditions_screen.dart';
import 'caregiver_patient_contacts_screen.dart';
import 'caregiver_patient_medications_screen.dart';

class CaregiverPatientHubScreen extends StatelessWidget {
  const CaregiverPatientHubScreen({
    super.key,
    required this.api,
    required this.patient,
  });

  final UleamMedApi api;
  final CaregiverPatient patient;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.fullName),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Selecciona un modulo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _PatientModuleCard(
            icon: Icons.medication,
            title: 'Medicamentos',
            subtitle: 'Gestionar tratamientos, fotos y tomas',
            color: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => CaregiverPatientMedicationsScreen(
                    api: api,
                    patient: patient,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PatientModuleCard(
            icon: Icons.event,
            title: 'Consultas',
            subtitle: 'Agendar y revisar citas medicas',
            color: AppColors.accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => AppointmentsScreen(
                    api: api,
                    caregiverPatientId: patient.id,
                    title: 'Consultas de ${patient.fullName}',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PatientModuleCard(
            icon: Icons.monitor_heart,
            title: 'Condiciones y alergias',
            subtitle: 'Enfermedades, alergias y perfil medico compartido',
            color: const Color(0xFF1565C0),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => ConditionsScreen(
                    api: api,
                    caregiverPatientId: patient.id,
                    title: 'Salud de ${patient.fullName}',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _PatientModuleCard(
            icon: Icons.contact_phone,
            title: 'Contactos de emergencia',
            subtitle: 'Ver contactos compartidos del paciente',
            color: const Color(0xFF00897B),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => CaregiverPatientContactsScreen(
                    api: api,
                    patientId: patient.id,
                    patientName: patient.fullName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PatientModuleCard extends StatelessWidget {
  const _PatientModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
