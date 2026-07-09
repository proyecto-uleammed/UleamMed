import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../widgets/app_states.dart';
import '../settings_screen.dart';

class CaregiverProfileScreen extends StatefulWidget {
  const CaregiverProfileScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.onLogout,
  });

  final UleamMedApi api;
  final AppSettingsController settings;
  final Future<void> Function() onLogout;

  @override
  State<CaregiverProfileScreen> createState() => _CaregiverProfileScreenState();
}

class _CaregiverProfileScreenState extends State<CaregiverProfileScreen> {
  final _nameController = TextEditingController();
  late Future<AppSession> _session = _load();
  bool _saving = false;

  Future<AppSession> _load() async {
    final session = await widget.api.loadAppSession();
    _nameController.text = session.user.fullName;
    return session;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.length < 3) {
      showAppSnackBar(context, 'Ingresa tu nombre completo', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateProfile(fullName: name);
      if (!mounted) {
        return;
      }
      setState(() {
        _session = Future.value(updated);
      });
      showAppSnackBar(context, 'Perfil actualizado');
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(settings: widget.settings),
              ),
            ),
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<AppSession>(
        future: _session,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ErrorStateView(
              onRetry: () => setState(() => _session = _load()),
            );
          }
          final user = snapshot.data!.user;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const CircleAvatar(
                radius: 38,
                child: Icon(Icons.family_restroom, size: 38),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: const Text('Correo electrónico'),
                subtitle: Text(user.email),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.badge_outlined),
                title: Text('Tipo de cuenta'),
                subtitle: Text('Cuidador'),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
