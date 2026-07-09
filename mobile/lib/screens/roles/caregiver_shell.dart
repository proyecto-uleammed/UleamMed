import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import 'caregiver_home_screen.dart';
import 'caregiver_patients_screen.dart';
import 'caregiver_profile_screen.dart';

/// Panel del cuidador: personas a cargo, alertas y mensajes.
class CaregiverShell extends StatelessWidget {
  const CaregiverShell({
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
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Personas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      tabs: [
        CaregiverHomeScreen(api: api, onLogout: onLogout, settings: settings),
        CaregiverPatientsScreen(api: api),
        CaregiverProfileScreen(
          api: api,
          settings: settings,
          onLogout: onLogout,
        ),
      ],
    );
  }
}
