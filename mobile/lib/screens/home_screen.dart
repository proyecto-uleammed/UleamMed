import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';
import '../widgets/upcoming_doses.dart';
import 'caregivers_screen.dart';
import 'conditions_screen.dart';
import 'emergency_screen.dart';
import 'medications_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.api,
    required this.onLogout,
    this.settings,
    this.onOpenTab,
  });

  final UleamMedApi? api;
  final Future<void> Function() onLogout;
  final AppSettingsController? settings;
  final ValueChanged<int>? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<DemoSession> _demoSession = _api.loadDemoSession();
  late Future<List<MedicationItem>> _medicationSummary = _api.listMedications();

  void _refreshSession() {
    setState(() {
      _demoSession = _api.loadDemoSession();
    });
  }

  void _refreshMedicationSummary() {
    setState(() {
      _medicationSummary = _api.listMedications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            actions: [
              if (widget.settings != null)
                IconButton(
                  tooltip: 'Ajustes y accesibilidad',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SettingsScreen(settings: widget.settings!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                ),
              IconButton(
                tooltip: 'Mi perfil',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileScreen(api: _api)),
                  );
                  if (mounted) {
                    _refreshSession();
                  }
                },
                icon: const Icon(Icons.account_circle),
              ),
              IconButton(
                tooltip: 'Cerrar sesion',
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'UleamMed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<DemoSession>(
                          future: _demoSession,
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.user.fullName.split(' ').first ??
                                'Paciente';
                            return Text(
                              'Hola, $name 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        const _DeviceDateTime(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.settings?.value.remindersEnabled ?? true) ...[
                    UpcomingDoses(
                      api: _api,
                      onChanged: _refreshMedicationSummary,
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Acciones rápidas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<MedicationItem>>(
                    future: _medicationSummary,
                    builder: (context, snapshot) {
                      return ActionCard(
                        icon: Icons.medication,
                        title: 'Medicamentos',
                        subtitle: _medicationSubtitle(snapshot),
                        color: AppColors.primary,
                        onTap: () async {
                          if (widget.onOpenTab != null) {
                            widget.onOpenTab!(1);
                            return;
                          }
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MedicationsScreen(api: _api),
                            ),
                          );
                          if (mounted) {
                            _refreshMedicationSummary();
                          }
                        },
                      );
                    },
                  ),
                  ActionCard(
                    icon: Icons.medical_information,
                    title: 'Perfil médico',
                    subtitle: 'Alergias, enfermedades y contacto clave',
                    color: AppColors.primaryDark,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(api: _api),
                        ),
                      );
                      if (mounted) {
                        _refreshSession();
                        _refreshMedicationSummary();
                      }
                    },
                  ),
                  ActionCard(
                    icon: Icons.health_and_safety,
                    title: 'Condiciones y alergias',
                    subtitle: 'Enfermedades y alergias con severidad',
                    color: const Color(0xFFC62828),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ConditionsScreen(api: _api),
                      ),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.calendar_month,
                    title: 'Citas médicas',
                    subtitle: 'Consulta y agenda tus citas',
                    color: AppColors.primaryLight,
                    onTap: () => widget.onOpenTab?.call(3),
                  ),
                  ActionCard(
                    icon: Icons.history,
                    title: 'Historial y cumplimiento',
                    subtitle: 'Revisa tus tomas de la semana',
                    color: AppColors.primary,
                    onTap: () => widget.onOpenTab?.call(2),
                  ),
                  ActionCard(
                    icon: Icons.family_restroom,
                    title: 'Cuidadores',
                    subtitle: 'Invita y gestiona permisos',
                    color: AppColors.primaryLight,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CaregiversScreen(api: _api),
                      ),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.emergency,
                    title: 'Emergencias',
                    subtitle: 'Contactos y llamada al 911',
                    color: const Color(0xFFC62828),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmergencyScreen(api: _api),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Resumen de hoy',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<MedicationItem>>(
                    future: _medicationSummary,
                    builder: (context, snapshot) {
                      final medications = snapshot.data;
                      if (medications == null) {
                        return const SizedBox.shrink();
                      }
                      if (medications.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.insights_outlined,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tu cumplimiento aparecera aqui',
                                style: Theme.of(context).textTheme.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cuando registres medicamentos y confirmes tus '
                                'tomas, veras el porcentaje de cumplimiento '
                                'del dia.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }
                      return _SummaryCard(
                        icon: Icons.medication,
                        label: 'Cumplimiento de medicamentos hoy',
                        value: _medicationPercent(snapshot),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _medicationSubtitle(AsyncSnapshot<List<MedicationItem>> snapshot) {
    final medications = snapshot.data;
    if (medications == null) {
      return 'Cargando...';
    }
    if (medications.isEmpty) {
      return 'Toca para agregar tus medicamentos';
    }

    final takenCount = medications
        .where((medication) => medication.taken)
        .length;
    return '$takenCount de ${medications.length} tomados hoy';
  }

  String _medicationPercent(AsyncSnapshot<List<MedicationItem>> snapshot) {
    final medications = snapshot.data;
    if (medications == null || medications.isEmpty) {
      return '--';
    }

    final takenCount = medications
        .where((medication) => medication.taken)
        .length;
    return '${((takenCount / medications.length) * 100).round()}%';
  }
}

/// Muestra la fecha y hora actuales tomadas del dispositivo (zona horaria
/// local incluida), actualizandose cada segundo.
class _DeviceDateTime extends StatefulWidget {
  const _DeviceDateTime();

  @override
  State<_DeviceDateTime> createState() => _DeviceDateTimeState();
}

class _DeviceDateTimeState extends State<_DeviceDateTime> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _dateLabel {
    final weekday = _weekdays[_now.weekday - 1];
    final month = _months[_now.month - 1];
    return '${_capitalize(weekday)}, ${_now.day} de $month de ${_now.year}';
  }

  String get _timeLabel {
    final hour = _now.hour.toString().padLeft(2, '0');
    final minute = _now.minute.toString().padLeft(2, '0');
    final second = _now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  String get _timeZoneLabel {
    final offset = _now.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final name = _now.timeZoneName;
    return '$name (UTC$sign$hours:$minutes)';
  }

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Colors.white.withValues(alpha: 0.85);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, size: 18, color: subtitleColor),
            const SizedBox(width: 6),
            Text(
              _timeLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _dateLabel,
          style: TextStyle(color: subtitleColor, fontSize: 15),
        ),
        Text(
          _timeZoneLabel,
          style: TextStyle(color: subtitleColor, fontSize: 12),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
