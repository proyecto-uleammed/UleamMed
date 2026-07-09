import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/notification_scheduler.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({
    super.key,
    required this.permissions,
    required this.scheduler,
    required this.api,
    this.onComplete,
    this.onLogout,
  });

  final PermissionService permissions;
  final NotificationScheduler scheduler;
  final UleamMedApi api;
  final VoidCallback? onComplete;
  final Future<void> Function()? onLogout;

  bool get isRequiredSetup => onComplete != null;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  ReminderPermissionSnapshot? _snapshot;
  bool _loading = true;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final snapshot = await widget.permissions.check();
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _requestNotifications() async {
    await widget.permissions.requestNotifications();
    await _refresh();
  }

  Future<void> _requestExactAlarms() async {
    await widget.permissions.requestExactAlarms();
    await _refresh();
  }

  Future<void> _requestFullScreen() async {
    await widget.permissions.requestFullScreen();
    await _refresh();
  }

  Future<void> _finish() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.isReady || _finishing) {
      return;
    }
    setState(() => _finishing = true);
    try {
      final medications = await widget.api.listMedications();
      await widget.scheduler.reconcile(medications);
      widget.onComplete?.call();
      if (!widget.isRequiredSetup && mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _finishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: widget.isRequiredSetup
          ? null
          : AppBar(title: const Text('Permisos y recordatorios')),
      body: SafeArea(
        child: _loading || snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.notifications_active,
                    size: 72,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Activa tus recordatorios',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'UleamMed necesita estos permisos para avisarte a la hora '
                    'de tomar tus medicamentos, incluso sin internet.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  _PermissionTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notificaciones',
                    description: 'Muestra el aviso en tu teléfono.',
                    state: snapshot.notifications,
                    onPressed: _requestNotifications,
                    onOpenSettings: widget.permissions.openSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.fullscreen,
                    title: 'Pantalla completa',
                    description:
                        'Permite que Android abra la alarma sobre la pantalla. '
                        'Si no esta activo, sonara como notificacion y deberas tocarla.',
                    state: snapshot.fullScreen,
                    onPressed: _requestFullScreen,
                    onOpenSettings: widget.permissions.openSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionTile(
                    icon: Icons.alarm,
                    title: 'Alarmas exactas',
                    description: 'Permite avisarte a la hora programada.',
                    state: snapshot.exactAlarms,
                    onPressed: _requestExactAlarms,
                    onOpenSettings: widget.permissions.openSettings,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: snapshot.isReady && !_finishing ? _finish : null,
                    icon: _finishing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      widget.isRequiredSetup ? 'Continuar' : 'Guardar',
                    ),
                  ),
                  if (widget.onLogout != null) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.state,
    required this.onPressed,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String description;
  final AppPermissionState state;
  final Future<void> Function() onPressed;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final granted = state == AppPermissionState.granted;
    final blocked = state == AppPermissionState.permanentlyDenied;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              granted ? Icons.check_circle : icon,
              size: 34,
              color: granted ? Colors.green : AppColors.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(description),
                  const SizedBox(height: 12),
                  if (granted)
                    const Text(
                      'Activado',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: blocked ? onOpenSettings : onPressed,
                      child: Text(blocked ? 'Abrir ajustes' : 'Permitir'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
