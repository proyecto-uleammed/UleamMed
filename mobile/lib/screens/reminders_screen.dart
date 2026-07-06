import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

/// Flujo educativo de recordatorios y permisos de notificacion (PB-024).
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.settings});

  final AppSettingsController settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          final enabled = settings.value.remindersEnabled;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.notifications_active,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Recordatorios de tus tomas',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Cuando los recordatorios estan activos, en la pantalla de '
                'inicio veras tus proximas tomas para marcarlas como tomadas, '
                'posponerlas o omitirlas.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  title: const Text('Activar recordatorios'),
                  subtitle: const Text(
                    'Muestra tus proximas tomas en el inicio.',
                  ),
                  value: enabled,
                  onChanged: (value) {
                    settings.setRemindersEnabled(value);
                    showAppSnackBar(
                      context,
                      value
                          ? 'Recordatorios activados'
                          : 'Recordatorios desactivados',
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              const _InfoNote(
                icon: Icons.info_outline,
                title: 'Permiso de notificaciones (Android 13+)',
                text:
                    'Para recibir avisos incluso con la app cerrada, tu '
                    'telefono pedira permiso de notificaciones. Puedes '
                    'aceptarlo cuando aparezca o activarlo luego desde los '
                    'ajustes del sistema.',
              ),
              const SizedBox(height: 12),
              const _InfoNote(
                icon: Icons.snooze,
                title: 'Posponer una toma',
                text:
                    'Si aun no puedes tomar tu medicina, usa "Posponer" y elige '
                    '10, 15, 30 o 60 minutos para que te la recuerde de nuevo.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
