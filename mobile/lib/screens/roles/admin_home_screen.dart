import 'package:flutter/material.dart';

import '../../models/admin_panel_data.dart';
import '../../models/app_role.dart';
import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/action_card.dart';
import '../../widgets/role_dashboard.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../settings_screen.dart';

/// Inicio del panel de administracion del sistema.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late final Future<AppSession> _session = widget.api.loadAppSession();
  late AdminDashboardStats _stats = AdminPanelData.dashboardStats();

  Future<void> _refreshAll() async {
    setState(() {
      _stats = AdminPanelData.dashboardStats();
      _session = widget.api.loadAppSession();
    });
    await _session;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    colors: [Color(0xFF37474F), Color(0xFF546E7A)],
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
                        _RoleBadge(label: AppRole.admin.label),
                        const SizedBox(height: 10),
                        FutureBuilder<AppSession>(
                          future: _session,
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.user.fullName.split(' ').first ??
                                'Admin';
                            return Text(
                              'Hola, $name',
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
                          'Supervisa usuarios, reportes y configuracion.',
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
                  Row(
                    children: [
                      RoleSummaryCard(
                        icon: Icons.person_outline,
                        label: 'Usuarios',
                        value: '${_stats.totalUsers}',
                      ),
                      const SizedBox(width: 12),
                      RoleSummaryCard(
                        icon: Icons.assessment_outlined,
                        label: 'Cumplimiento',
                        value: '${_stats.compliancePercent}%',
                        color: const Color(0xFF546E7A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Administracion',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ActionCard(
                    icon: Icons.manage_accounts,
                    title: 'Usuarios',
                    subtitle: 'Gestion de cuentas y roles',
                    color: const Color(0xFF37474F),
                    onTap: () => openRoleTab(context, 1),
                  ),
                  ActionCard(
                    icon: Icons.bar_chart,
                    title: 'Reportes',
                    subtitle: 'Estadisticas de uso y cumplimiento',
                    color: AppColors.primary,
                    onTap: () => openRoleTab(context, 2),
                  ),
                  ActionCard(
                    icon: Icons.settings_applications,
                    title: 'Sistema',
                    subtitle: 'Configuracion general de la plataforma',
                    color: AppColors.primaryDark,
                    onTap: () => openRoleTab(context, 3),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
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
