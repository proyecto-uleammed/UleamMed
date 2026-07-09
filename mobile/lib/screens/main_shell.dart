import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'roles/caregiver_shell.dart';
import 'roles/patient_shell.dart';

/// Enruta usando exclusivamente el rol confirmado por el backend.
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
    required this.role,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;
  final AppRole role;

  @override
  Widget build(BuildContext context) {
    if (role == AppRole.patient) {
      return PatientShell(api: api, onLogout: onLogout, settings: settings);
    }
    if (role == AppRole.caregiver) {
      return CaregiverShell(api: api, onLogout: onLogout, settings: settings);
    }
    return _UnsupportedRoleScreen(role: role, onLogout: onLogout);
  }
}

class _UnsupportedRoleScreen extends StatelessWidget {
  const _UnsupportedRoleScreen({required this.role, required this.onLogout});

  final AppRole role;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso no disponible'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesion',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            role == AppRole.unknown
                ? 'Tu cuenta tiene un rol no reconocido.'
                : 'El panel de ${role.label.toLowerCase()} aun no esta habilitado.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
