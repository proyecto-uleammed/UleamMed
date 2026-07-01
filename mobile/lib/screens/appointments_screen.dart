import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  static const _appointments = [
  _Appointment(
    doctor: 'Dra. María González',
    specialty: 'Medicina General',
    date: '28 Jun 2026',
    time: '10:30',
    location: 'Centro de Salud Norte',
  ),
  _Appointment(
    doctor: 'Dr. Carlos Ruiz',
    specialty: 'Cardiología',
    date: '05 Jul 2026',
    time: '15:00',
    location: 'Hospital Regional',
  ),
  _Appointment(
    doctor: 'Dra. Ana Pérez',
    specialty: 'Oftalmología',
    date: '12 Jul 2026',
    time: '09:00',
    location: 'Clínica Visión',
  ),
];

  @override
  Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Citas Médicas')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: _appointments.map((apt) => _AppointmentCard(appointment: apt)).toList(),
    ),
  );
  }
}

class _Appointment {
  const _Appointment({
    required this.doctor,
    required this.specialty,
    required this.date,
    required this.time,
    required this.location,
  });

  final String doctor;
  final String specialty;
  final String date;
  final String time;
  final String location;
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final _Appointment appointment;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  child: const Icon(Icons.calendar_month, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(appointment.doctor, style: Theme.of(context).textTheme.titleLarge),
                      Text(appointment.specialty, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.event, text: '${appointment.date} · ${appointment.time}'),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.location_on_outlined, text: appointment.location),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}
