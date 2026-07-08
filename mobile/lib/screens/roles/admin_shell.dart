import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../profile_screen.dart';
import 'admin_home_screen.dart';
import 'role_section_placeholder.dart';

/// Panel del administrador: usuarios, reportes y sistema.
class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return RoleShellScaffold(
      api: api,
      settings: settings,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.manage_accounts_outlined),
          selectedIcon: Icon(Icons.manage_accounts),
          label: 'Usuarios',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Reportes',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Sistema',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      tabs: [
        AdminHomeScreen(
          api: api,
          onLogout: onLogout,
          settings: settings,
        ),
        const RoleSectionPlaceholder(
          title: 'Gestion de usuarios',
          description:
              'Administra cuentas, roles, permisos e invitaciones de '
              'cuidadores.',
          icon: Icons.manage_accounts,
        ),
        const RoleSectionPlaceholder(
          title: 'Reportes',
          description:
              'Estadisticas de uso, cumplimiento de medicamentos e '
              'incidencias del sistema.',
          icon: Icons.assessment,
        ),
        const RoleSectionPlaceholder(
          title: 'Configuracion del sistema',
          description:
              'Parametros generales, respaldos y mantenimiento de la '
              'plataforma.',
          icon: Icons.settings_applications,
        ),
        ProfileScreen(api: api, settings: settings),
      ],
    );
  }
}
