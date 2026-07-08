import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'roles/admin_shell.dart';
import 'roles/caregiver_shell.dart';
import 'roles/patient_shell.dart';
import 'roles/professional_shell.dart';

/// Enruta al panel correspondiente segun el rol activo (PB-006).
class MainShell extends StatelessWidget {
  const MainShell({
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
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final role = settings.value.role;
        final key = ValueKey(role);

        return switch (role) {
          AppRole.patient => PatientShell(
            key: key,
            api: api,
            onLogout: onLogout,
            settings: settings,
          ),
          AppRole.caregiver => CaregiverShell(
            key: key,
            api: api,
            onLogout: onLogout,
            settings: settings,
          ),
          AppRole.professional => ProfessionalShell(
            key: key,
            api: api,
            onLogout: onLogout,
            settings: settings,
          ),
          AppRole.admin => AdminShell(
            key: key,
            api: api,
            onLogout: onLogout,
            settings: settings,
          ),
        };
      },
    );
  }
}
