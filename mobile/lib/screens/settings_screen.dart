import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';

/// Ajustes de accesibilidad y rol (PB-010/006).
/// Las secciones de privacidad y bloqueo se agregan en la fase de privacidad.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final AppSettingsController settings;

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
              ...FontScaleOption.values.map(
                (option) {
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
                },
              ),
              const Divider(height: 32),
              _SectionTitle(
                icon: Icons.badge_outlined,
                title: 'Rol dentro de la app',
              ),
              const SizedBox(height: 8),
              Text(
                'Adapta el menu visible. Los permisos reales se validan en el '
                'servidor.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AppRole>(
                initialValue: current.role,
                decoration: const InputDecoration(
                  labelText: 'Rol actual',
                  prefixIcon: Icon(Icons.person_pin),
                  border: OutlineInputBorder(),
                ),
                items: AppRole.values
                    .map(
                      (role) => DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (role) {
                  if (role != null) {
                    settings.setRole(role);
                  }
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
