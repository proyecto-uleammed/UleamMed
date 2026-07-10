import 'package:flutter/material.dart';

import '../../models/admin_panel_data.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_states.dart';

class AdminSystemScreen extends StatefulWidget {
  const AdminSystemScreen({super.key, required this.api});

  final UleamMedApi api;

  @override
  State<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends State<AdminSystemScreen> {
  late Future<AppSession> _session = widget.api.loadAppSession();

  Future<void> _refresh() async {
    setState(() {
      _session = widget.api.loadAppSession();
    });
    await _session;
  }

  void _showPendingAction(String action) {
    showAppSnackBar(
      context,
      '$action estara disponible cuando el modulo de administracion '
      'del backend este listo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion del sistema'),
      ),
      body: FutureBuilder<AppSession>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(),
            );
          }
          final session = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conexion actual',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(
                          icon: Icons.cloud_outlined,
                          label: 'Backend',
                          value: session.apiUrl,
                        ),
                        _InfoRow(
                          icon: Icons.public,
                          label: 'Entorno',
                          value: session.environment,
                        ),
                        _InfoRow(
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Sesion',
                          value: session.user.email,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Modulos de la plataforma',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ...AdminPanelData.systemModules.map(
                  (module) => _SystemModuleTile(module: module),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mantenimiento',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.backup_outlined),
                        title: const Text('Respaldos'),
                        subtitle: const Text(
                          'Programar respaldo de base de datos',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPendingAction('Los respaldos'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.cleaning_services_outlined),
                        title: const Text('Limpiar cache'),
                        subtitle: const Text(
                          'Invalidar sesiones y datos temporales',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showPendingAction('La limpieza de cache'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('Correo del sistema'),
                        subtitle: const Text('Revisar plantillas y SMTP'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _showPendingAction('La configuracion de correo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemModuleTile extends StatelessWidget {
  const _SystemModuleTile({required this.module});

  final AdminSystemModule module;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (module.status) {
      AdminModuleStatus.operational => (
        Icons.check_circle,
        AppColors.primary,
        'Operativo',
      ),
      AdminModuleStatus.pending => (
        Icons.schedule,
        AppColors.textSecondary,
        'Pendiente',
      ),
      AdminModuleStatus.degraded => (
        Icons.warning_amber_rounded,
        const Color(0xFFF57C00),
        'Atencion',
      ),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(module.name),
        subtitle: Text(module.description),
        trailing: Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
