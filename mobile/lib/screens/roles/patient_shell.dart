import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../appointments_screen.dart';
import '../history_screen.dart';
import '../home_screen.dart';
import '../medications_screen.dart';
import '../profile_screen.dart';

/// Panel del paciente: medicamentos, historial y consultas propias.
class PatientShell extends StatelessWidget {
  const PatientShell({
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
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: 'Medicinas',
        ),
        NavigationDestination(
          icon: Icon(Icons.history),
          selectedIcon: Icon(Icons.history_toggle_off),
          label: 'Historial',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: 'Consultas',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      tabs: [
        _PatientHomeTab(
          api: api,
          onLogout: onLogout,
          settings: settings,
        ),
        MedicationsScreen(api: api),
        HistoryScreen(api: api),
        AppointmentsScreen(api: api),
        ProfileScreen(api: api, settings: settings),
      ],
    );
  }
}

class _PatientHomeTab extends StatelessWidget {
  const _PatientHomeTab({
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      api: api,
      onLogout: onLogout,
      settings: settings,
      onOpenTab: (index) => openRoleTab(context, index),
    );
  }
}
