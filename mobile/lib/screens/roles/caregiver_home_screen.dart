import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/action_card.dart';
import '../../widgets/role_dashboard.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../settings_screen.dart';

/// Inicio del panel de cuidador: resumen de personas a cargo y alertas.
class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  late final Future<DemoSession> _session = widget.api.loadDemoSession();

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
                        _RoleBadge(label: AppRole.caregiver.label),
                        const SizedBox(height: 10),
                        FutureBuilder<DemoSession>(
                          future: _session,
                          builder: (context, snapshot) {
                            final name =
                                snapshot.data?.user.fullName.split(' ').first ??
                                'Cuidador';
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
                          'Apoya a tus familiares con recordatorios y alertas.',
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
                        icon: Icons.family_restroom,
                        label: 'Personas a cargo',
                        value: '0',
                      ),
                      SizedBox(width: 12),
                      RoleSummaryCard(
                        icon: Icons.notifications_active,
                        label: 'Alertas hoy',
                        value: '0',
                        color: Color(0xFFC62828),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acciones del cuidador',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  ActionCard(
                    icon: Icons.people,
                    title: 'Personas a cargo',
                    subtitle: 'Ver salud y medicamentos compartidos',
                    color: AppColors.primary,
                    onTap: () => openRoleTab(context, 1),
                  ),
                  ActionCard(
                    icon: Icons.warning_amber,
                    title: 'Alertas',
                    subtitle: 'Tomas omitidas y avisos importantes',
                    color: const Color(0xFFC62828),
                    onTap: () => openRoleTab(context, 2),
                  ),
                  ActionCard(
                    icon: Icons.forum_outlined,
                    title: 'Mensajes',
                    subtitle: 'Comunicacion con pacientes y medicos',
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
