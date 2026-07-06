import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/action_card.dart';
import '../widgets/upcoming_doses.dart';
import 'activities_screen.dart';
import 'caregivers_screen.dart';
import 'conditions_screen.dart';
import 'emergency_screen.dart';
import 'medications_screen.dart';
import 'pending_sync_screen.dart';
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
  late Future<int> _pendingSync = _api.pendingSyncCount();

  void _refreshSession() {
    setState(() {
      _demoSession = _api.loadDemoSession();
    });
  }

  void _refreshMedicationSummary() {
    setState(() {
      _medicationSummary = _api.listMedications();
      _pendingSync = _api.pendingSyncCount();
    });
  }

  void _refreshSyncStatus() {
    setState(() {
      _pendingSync = _api.pendingSyncCount();
    });
  }

  Future<void> _synchronizePendingChanges() async {
    final result = await _api.synchronizePendingChanges();
    if (!mounted) {
      return;
    }
    _refreshSyncStatus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
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
                        const SizedBox(height: 4),
                        Text(
                          '¿Cómo te sientes hoy?',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 18,
                          ),
                        ),
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
                  _MoodSelector(),
                  const SizedBox(height: 16),
                  _BackendStatusCard(
                    session: _demoSession,
                    onRefresh: _refreshSession,
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<int>(
                    future: _pendingSync,
                    builder: (context, snapshot) {
                      return _OfflineStatusCard(
                        pendingCount: snapshot.data ?? 0,
                        onSync: _synchronizePendingChanges,
                      );
                    },
                  ),
                  if (widget.settings?.value.remindersEnabled ?? true) ...[
                    const SizedBox(height: 24),
                    UpcomingDoses(
                      api: _api,
                      onChanged: _refreshMedicationSummary,
                    ),
                  ],
                  const SizedBox(height: 24),
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
                        _refreshSyncStatus();
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
                    icon: Icons.sync,
                    title: 'Sincronización',
                    subtitle: 'Revisa los cambios pendientes',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PendingSyncScreen(api: _api),
                      ),
                    ),
                  ),
                  ActionCard(
                    icon: Icons.fitness_center,
                    title: 'Actividades del día',
                    subtitle: 'Caminata, estiramientos y más',
                    color: AppColors.primaryDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ActivitiesScreen(),
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
                      return _SummaryRow(
                        medicationValue: _medicationPercent(snapshot),
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
    if (medications == null || medications.isEmpty) {
      if (snapshot.hasError) {
        return 'Backend no disponible';
      }
      return 'Cargando medicamentos';
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

class _BackendStatusCard extends StatelessWidget {
  const _BackendStatusCard({required this.session, required this.onRefresh});

  final Future<DemoSession> session;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DemoSession>(
      future: session,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final demo = snapshot.data;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasError ? const Color(0xFFFFF3E0) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFFFB74D)
                  : AppColors.accent.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasError ? const Color(0xFFFFE0B2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  hasError ? Icons.cloud_off : Icons.cloud_done,
                  color: hasError ? const Color(0xFFE65100) : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoading
                          ? 'Conectando backend...'
                          : hasError
                          ? 'Backend no disponible'
                          : 'Backend conectado',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText(snapshot),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                    ),
                    if (demo != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatusChip(
                            icon: Icons.person,
                            label: demo.user.fullName,
                          ),
                          _StatusChip(
                            icon: Icons.email,
                            label: demo.user.email,
                          ),
                          _StatusChip(icon: Icons.api, label: demo.environment),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar conexion',
                onPressed: isLoading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        );
      },
    );
  }

  String _statusText(AsyncSnapshot<DemoSession> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return 'Validando conexion y perfil del usuario.';
    }

    if (snapshot.hasError) {
      return 'Levanta FastAPI en el puerto 8000 y vuelve a intentar.';
    }

    final demo = snapshot.data;
    if (demo == null) {
      return 'Sin datos del backend todavia.';
    }

    return 'Sesion activa desde ${demo.apiUrl}.';
  }
}

class _OfflineStatusCard extends StatelessWidget {
  const _OfflineStatusCard({required this.pendingCount, required this.onSync});

  final int pendingCount;
  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final hasPending = pendingCount > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasPending ? const Color(0xFFFFF8E1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasPending
              ? const Color(0xFFFFCA28)
              : AppColors.accent.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasPending ? const Color(0xFFFFECB3) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasPending ? Icons.sync_problem : Icons.offline_pin,
              color: hasPending ? const Color(0xFFF57F17) : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPending
                      ? '$pendingCount cambios pendientes'
                      : 'Datos listos sin conexion',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  hasPending
                      ? 'Se guardaron en este dispositivo y se enviaran cuando exista contrato de sincronizacion.'
                      : 'Puedes consultar perfil, medicamentos y tomas guardadas.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: onSync,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodSelector extends StatefulWidget {
  @override
  State<_MoodSelector> createState() => _MoodSelectorState();
}

class _MoodSelectorState extends State<_MoodSelector> {
  int? _selectedMood;

  static const _moods = [
    (Icons.sentiment_very_satisfied, 'Bien'),
    (Icons.sentiment_neutral, 'Regular'),
    (Icons.sentiment_dissatisfied, 'Mal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu estado de ánimo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_moods.length, (index) {
              final isSelected = _selectedMood == index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < _moods.length - 1 ? 8 : 0,
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedMood = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.accent,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _moods[index].$1,
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _moods[index].$2,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.medicationValue});

  final String medicationValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.medication,
            label: 'Medicamentos',
            value: medicationValue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.directions_walk,
            label: 'Actividad',
            value: '25%',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.water_drop,
            label: 'Agua',
            value: '4/8',
          ),
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
