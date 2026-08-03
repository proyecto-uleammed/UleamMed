import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';
import 'conditions_screen.dart';

/// Historial de salud del paciente: cumplimiento, datos medicos y condiciones
/// (solo lectura; la edicion la realiza el cuidador).
class PatientHealthHistoryScreen extends StatefulWidget {
  const PatientHealthHistoryScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<PatientHealthHistoryScreen> createState() =>
      _PatientHealthHistoryScreenState();
}

class _PatientHealthHistoryScreenState extends State<PatientHealthHistoryScreen> {
  late final UleamMedApi _api = widget.api ?? AppScope.of(context).api;
  late Future<_HealthHistoryData> _data = _load();

  Future<_HealthHistoryData> _load() async {
    final results = await Future.wait([
      _api.loadMedicalProfile(),
      _api.listHealthEntries(),
      _api.listDoseConfirmations(),
    ]);
    return _HealthHistoryData(
      profile: results[0] as MedicalProfile,
      entries: results[1] as List<HealthEntry>,
      confirmations: results[2] as List<DoseConfirmation>,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _load();
    });
    await _data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi salud'),
      ),
      body: FutureBuilder<_HealthHistoryData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Cargando tu historial...');
          }
          if (snapshot.hasError) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(
                title: 'No se pudo cargar tu historial',
              ),
            );
          }

          final data = snapshot.data ?? const _HealthHistoryData();
          final conditions = data.entries
              .where((entry) => entry.kind == HealthEntryKind.condition)
              .toList();
          final allergies = data.entries
              .where((entry) => entry.kind == HealthEntryKind.allergy)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Resumen de tu tratamiento',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu cuidador actualiza esta informacion. '
                  'Aqui puedes revisar como va tu salud.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                _WeeklyComplianceSection(confirmations: data.confirmations),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.monitor_heart_outlined,
                  title: 'Signos y datos medicos',
                ),
                const SizedBox(height: 8),
                _VitalsSection(profile: data.profile),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.healing_outlined,
                  title: 'Enfermedades y condiciones',
                ),
                const SizedBox(height: 8),
                if (conditions.isEmpty)
                  const _InlineHint(
                    text:
                        'Aun no hay condiciones registradas. '
                        'Tu cuidador las agregara cuando sea necesario.',
                  )
                else
                  ...conditions.map(
                    (entry) => _ReadOnlyHealthCard(
                      entry: entry,
                      onTap: () => showHealthEntryDetail(context, entry),
                    ),
                  ),
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.warning_amber_outlined,
                  title: 'Alergias',
                ),
                const SizedBox(height: 8),
                if (allergies.isEmpty)
                  const _InlineHint(
                    text: 'No hay alergias registradas por el momento.',
                  )
                else
                  ...allergies.map(
                    (entry) => _ReadOnlyHealthCard(
                      entry: entry,
                      onTap: () => showHealthEntryDetail(context, entry),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HealthHistoryData {
  const _HealthHistoryData({
    this.profile = const MedicalProfile(),
    this.entries = const [],
    this.confirmations = const [],
  });

  final MedicalProfile profile;
  final List<HealthEntry> entries;
  final List<DoseConfirmation> confirmations;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
      ],
    );
  }
}

class _InlineHint extends StatelessWidget {
  const _InlineHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _VitalsSection extends StatelessWidget {
  const _VitalsSection({required this.profile});

  final MedicalProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <_InfoTile>[
      if (profile.birthDate.isNotEmpty)
        _InfoTile(
          icon: Icons.cake_outlined,
          label: 'Fecha de nacimiento',
          value: profile.birthDate,
        ),
      if (profile.bloodType.isNotEmpty)
        _InfoTile(
          icon: Icons.bloodtype,
          label: 'Tipo de sangre',
          value: profile.bloodType,
        ),
      if (profile.emergencyContactName.isNotEmpty)
        _InfoTile(
          icon: Icons.contact_phone_outlined,
          label: 'Contacto de emergencia',
          value:
              '${profile.emergencyContactName} (${profile.emergencyContactPhone})',
        ),
      if (profile.importantNotes.isNotEmpty)
        _InfoTile(
          icon: Icons.notes,
          label: 'Indicaciones importantes',
          value: profile.importantNotes,
        ),
    ];

    if (items.isEmpty) {
      return const _InlineHint(
        text:
            'Tu cuidador registrara tus signos vitales y datos medicos '
            'desde su panel.',
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeeklyComplianceSection extends StatelessWidget {
  const _WeeklyComplianceSection({required this.confirmations});

  final List<DoseConfirmation> confirmations;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = confirmations
        .where((item) => item.recordedAt.isAfter(weekAgo))
        .toList();
    final taken = week.where((item) => item.status == DoseStatus.taken).length;
    final total = week.length;
    final percent = total == 0 ? 0 : ((taken / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumplimiento de medicamentos (7 dias)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: total == 0 ? 0 : taken / total,
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  total == 0
                      ? 'Aun no hay registros de tomas esta semana.'
                      : '$taken de $total tomas confirmadas como tomadas.',
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyHealthCard extends StatelessWidget {
  const _ReadOnlyHealthCard({required this.entry, required this.onTap});

  final HealthEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(entry.severity);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (entry.detail.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        entry.detail,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      entry.active ? 'En tratamiento' : 'Controlada',
                      style: TextStyle(
                        color: entry.active
                            ? AppColors.primary
                            : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color),
                ),
                child: Text(
                  entry.severity.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showHealthEntryDetail(
  BuildContext context,
  HealthEntry entry,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Tipo',
              value: entry.kind == HealthEntryKind.allergy
                  ? 'Alergia'
                  : 'Condicion',
            ),
            _DetailRow(label: 'Severidad', value: entry.severity.label),
            _DetailRow(
              label: 'Estado',
              value: entry.active ? 'En tratamiento' : 'Controlada',
            ),
            if (entry.date.isNotEmpty)
              _DetailRow(label: 'Fecha aproximada', value: entry.date),
            if (entry.detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Detalle',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                entry.detail,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
