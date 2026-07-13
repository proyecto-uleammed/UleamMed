import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../services/notification_scheduler.dart';
import '../../services/permission_service.dart';
import '../../widgets/role_shell_scaffold.dart';
import '../appointments_screen.dart';
import '../medications_screen.dart';
import '../patient_health_history_screen.dart';

/// Panel del paciente simplificado para adultos mayores:
/// medicamentos, consultas e historial de salud (solo lectura).
class PatientShell extends StatelessWidget {
  const PatientShell({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
    required this.permissionService,
    required this.notificationScheduler,
    this.initialTab = 0,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;
  final PermissionService permissionService;
  final NotificationScheduler notificationScheduler;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return RoleShellScaffold(
      api: api,
      settings: settings,
      initialIndex: initialTab,
      patientMode: true,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.medication_outlined),
          selectedIcon: Icon(Icons.medication),
          label: 'Medicinas',
        ),
        NavigationDestination(
          icon: Icon(Icons.event_outlined),
          selectedIcon: Icon(Icons.event),
          label: 'Consultas',
        ),
        NavigationDestination(
          icon: Icon(Icons.monitor_heart_outlined),
          selectedIcon: Icon(Icons.monitor_heart),
          label: 'Mi salud',
        ),
      ],
      tabs: [
        MedicationsScreen(
          api: api,
          notificationScheduler: notificationScheduler,
          shellTabIndex: 0,
          readOnly: true,
          settings: settings,
          permissionService: permissionService,
          onLogout: onLogout,
        ),
        AppointmentsScreen(
          api: api,
          shellTabIndex: 1,
          readOnly: true,
        ),
        PatientHealthHistoryScreen(api: api),
      ],
    );
  }
}
