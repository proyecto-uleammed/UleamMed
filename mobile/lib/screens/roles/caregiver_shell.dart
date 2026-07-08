import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../profile_screen.dart';
import 'caregiver_home_screen.dart';
import 'role_section_placeholder.dart';

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
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications),
          label: 'Alertas',
        ),
        NavigationDestination(
          icon: Icon(Icons.forum_outlined),
          selectedIcon: Icon(Icons.forum),
          label: 'Mensajes',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      tabs: [
        CaregiverHomeScreen(
          api: api,
          onLogout: onLogout,
          settings: settings,
        ),
        const RoleSectionPlaceholder(
          title: 'Personas a cargo',
          description:
              'Aqui veras a quienes cuidas, su cumplimiento de medicamentos '
              'y datos compartidos contigo.',
          icon: Icons.family_restroom,
        ),
        const RoleSectionPlaceholder(
          title: 'Alertas',
          description:
              'Recibiras avisos cuando falte una toma importante o haya '
              'cambios en la salud de tus familiares.',
          icon: Icons.warning_amber,
        ),
        const RoleSectionPlaceholder(
          title: 'Mensajes',
          description:
              'Canal de comunicacion con pacientes y profesionales de salud.',
          icon: Icons.forum_outlined,
        ),
        ProfileScreen(api: api, settings: settings),
      ],
    );
  }
}
