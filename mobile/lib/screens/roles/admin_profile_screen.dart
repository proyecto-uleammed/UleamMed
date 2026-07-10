import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/app_settings.dart';
import '../../utils/form_inputs.dart';
import '../../widgets/app_states.dart';
import '../settings_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({
    super.key,
    required this.api,
    required this.settings,
    required this.onLogout,
  });

  final UleamMedApi api;
  final AppSettingsController settings;
  final Future<void> Function() onLogout;

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _refresh() async {
    setState(() {
      _session = _load();
    });
    await _session;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      final updated = await widget.api.updateProfile(
        fullName: _nameController.text.trim(),
      );
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
            tooltip: 'Cerrar sesion',
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
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(
                title: 'No se pudo cargar el perfil',
              ),
            );
          }
          final user = snapshot.data!.user;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: Form(
            key: _formKey,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: Color(0xFF546E7A),
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  inputFormatters: FormInputs.personName,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => FormInputs.personNameValidator(value),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Correo electronico'),
                  subtitle: Text(user.email),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.badge_outlined),
                  title: Text('Tipo de cuenta'),
                  subtitle: Text('Administrador'),
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
            ),
            ),
          );
        },
      ),
    );
  }
}
