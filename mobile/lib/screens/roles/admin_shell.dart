import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import 'admin_home_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_system_screen.dart';
import 'admin_users_screen.dart';

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
        AdminHomeScreen(api: api, onLogout: onLogout, settings: settings),
        const AdminUsersScreen(),
        const AdminReportsScreen(),
        AdminSystemScreen(api: api),
        AdminProfileScreen(
          api: api,
          settings: settings,
          onLogout: onLogout,
        ),
      ],
    );
  }
}
