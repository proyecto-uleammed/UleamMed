import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/action_card.dart';
import '../../widgets/role_dashboard.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../settings_screen.dart';

/// Inicio del panel medico: pacientes e indicaciones.
class ProfessionalHomeScreen extends StatefulWidget {
  const ProfessionalHomeScreen({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  State<ProfessionalHomeScreen> createState() => _ProfessionalHomeScreenState();
}

class _ProfessionalHomeScreenState extends State<ProfessionalHomeScreen> {
  late final Future<AppSession> _session = widget.api.loadAppSession();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            actions: [
              IconButton(
                tooltip: 'Ajustes',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(settings: widget.settings),
                  ),
                ),
                icon: const Icon(Icons.settings),
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
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
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
                        _RoleBadge(label: AppRole.professional.label),
                        const SizedBox(height: 10),
                        FutureBuilder<AppSession>(
                          future: _session,
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.user.fullName.split(' ').first ??
                                'Doctor';
                            return Text(
                              'Dr(a). $name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Revisa pacientes, indicaciones y agenda clinica.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
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
                  const Row(
                    children: [
                      RoleSummaryCard(
                        icon: Icons.people_outline,
                        label: 'Pacientes',
                        value: '0',
                      ),
                      SizedBox(width: 12),
                      RoleSummaryCard(
                        icon: Icons.event_available,
                        label: 'Citas hoy',
                        value: '0',
                        color: AppColors.primaryLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acciones medicas',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ActionCard(
                    icon: Icons.groups,
                    title: 'Mis pacientes',
                    subtitle: 'Historial y datos compartidos',
                    color: AppColors.primary,
                    onTap: () => openRoleTab(context, 1),
                  ),
                  ActionCard(
                    icon: Icons.edit_note,
                    title: 'Indicaciones',
                    subtitle: 'Medicamentos y recomendaciones',
                    color: AppColors.primaryDark,
                    onTap: () => openRoleTab(context, 2),
                  ),
                  ActionCard(
                    icon: Icons.calendar_month,
                    title: 'Agenda',
                    subtitle: 'Consultas programadas',
                    color: AppColors.primaryLight,
                    onTap: () => openRoleTab(context, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Panel $label',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
