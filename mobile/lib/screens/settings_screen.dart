import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/api_service.dart';
import '../services/notification_scheduler.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';
import 'legal_screen.dart';
import 'lock_setup_screen.dart';
import 'permissions_screen.dart';

/// Ajustes de accesibilidad, recordatorios y privacidad.
/// Las secciones de privacidad y bloqueo se agregan en la fase de privacidad.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.api,
    this.permissionService,
    this.notificationScheduler,
  });

  final AppSettingsController settings;
  final UleamMedApi? api;
  final PermissionService? permissionService;
  final NotificationScheduler? notificationScheduler;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final current = settings.value;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(icon: Icons.format_size, title: 'Tamano de letra'),
              const SizedBox(height: 8),
              Text(
                'Elige el tamano que te resulte mas comodo para leer.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ...FontScaleOption.values.map((option) {
                final selected = current.fontScale == option;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => settings.setFontScale(option),
                    leading: Text(
                      'Aa',
                      style: TextStyle(
                        fontSize: 18 * option.factor,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(option.label),
                    trailing: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              }),
              const Divider(height: 32),
              _SectionTitle(
                icon: Icons.notifications_active_outlined,
                title: 'Recordatorios',
              ),
              const SizedBox(height: 8),
              if (api != null &&
                  permissionService != null &&
                  notificationScheduler != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Permisos y recordatorios'),
                  subtitle: const Text(
                    'Revisa notificaciones y alarmas exactas.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PermissionsScreen(
                          permissions: permissionService!,
                          scheduler: notificationScheduler!,
                          api: api!,
                        ),
                      ),
                    );
                  },
                ),
              const Divider(height: 32),
              _SectionTitle(
                icon: Icons.lock_outline,
                title: 'Privacidad y seguridad',
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloqueo de la app'),
                subtitle: const Text('Pide un PIN al abrir la aplicacion.'),
                value: current.appLockEnabled,
                onChanged: (enabled) async {
                  if (enabled) {
                    final ok = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LockSetupScreen(settings: settings),
                      ),
                    );
                    if (ok == true && context.mounted) {
                      showAppSnackBar(context, 'Bloqueo activado');
                    }
                  } else {
                    await settings.setAppLock(enabled: false);
                    if (context.mounted) {
                      showAppSnackBar(context, 'Bloqueo desactivado');
                    }
                  }
                },
              ),
              if (current.appLockEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Bloqueo automatico'),
                  subtitle: Text(
                    'Tras ${current.autoLockMinutes} min en segundo plano',
                  ),
                  trailing: DropdownButton<int>(
                    value: current.autoLockMinutes,
                    items: const [1, 2, 5, 10]
                        .map(
                          (minutes) => DropdownMenuItem(
                            value: minutes,
                            child: Text('$minutes min'),
                          ),
                        )
                        .toList(),
                    onChanged: (minutes) {
                      if (minutes != null) {
                        settings.setAppLock(
                          enabled: true,
                          autoLockMinutes: minutes,
                        );
                      }
                    },
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terminos y privacidad'),
                subtitle: Text(
                  current.termsAccepted
                      ? 'Aceptados (v${current.termsAcceptedVersion})'
                      : 'Pendiente de aceptar',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalScreen(settings: settings),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}
