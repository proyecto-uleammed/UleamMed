import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../profile_screen.dart';
import 'professional_home_screen.dart';
import 'role_section_placeholder.dart';

/// Panel del medico: pacientes, indicaciones y agenda.
class ProfessionalShell extends StatelessWidget {
  const ProfessionalShell({
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
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Pacientes',
        ),
        NavigationDestination(
          icon: Icon(Icons.edit_note_outlined),
          selectedIcon: Icon(Icons.edit_note),
          label: 'Indicaciones',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: 'Agenda',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      tabs: [
        ProfessionalHomeScreen(
          api: api,
          onLogout: onLogout,
          settings: settings,
        ),
        const RoleSectionPlaceholder(
          title: 'Pacientes',
          description:
              'Lista de pacientes vinculados con acceso a historial, '
              'medicamentos y cumplimiento.',
          icon: Icons.groups,
        ),
        const RoleSectionPlaceholder(
          title: 'Indicaciones medicas',
          description:
              'Registra y actualiza medicamentos, dosis e instrucciones '
              'para tus pacientes.',
          icon: Icons.medication_liquid,
        ),
        const RoleSectionPlaceholder(
          title: 'Agenda clinica',
          description:
              'Consultas programadas, seguimientos y recordatorios '
              'profesionales.',
          icon: Icons.calendar_month,
        ),
        ProfileScreen(api: api, settings: settings),
      ],
    );
  }
}
