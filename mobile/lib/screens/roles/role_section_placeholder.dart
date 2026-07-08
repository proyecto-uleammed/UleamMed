import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Seccion provisional dentro de un panel de rol hasta personalizarla.
class RoleSectionPlaceholder extends StatelessWidget {
  const RoleSectionPlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.actions = const [],
  });

  final String title;
  final String description;
  final IconData icon;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(icon, size: 56, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Esta seccion forma parte del panel de tu rol. La '
            'personalizaremos en el siguiente paso.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...actions,
          ],
        ],
      ),
    );
  }
}
