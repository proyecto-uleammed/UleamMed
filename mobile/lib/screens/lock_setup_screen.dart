import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/lock_service.dart';

/// Configuracion del PIN de bloqueo local (PB-053).
class LockSetupScreen extends StatefulWidget {
  const LockSetupScreen({super.key, required this.settings, this.lockService});

  final AppSettingsController settings;
  final LockService? lockService;

  @override
  State<LockSetupScreen> createState() => _LockSetupScreenState();
}

class _LockSetupScreenState extends State<LockSetupScreen> {
  late final LockService _lock = widget.lockService ?? LockService();
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    await _lock.setPin(_pinController.text.trim());
    await widget.settings.setAppLock(
      enabled: true,
      autoLockMinutes: widget.settings.value.autoLockMinutes,
    );
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar bloqueo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              'Crea un PIN de 4 a 6 digitos para proteger tu informacion.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final pin = (value ?? '').trim();
                if (pin.length < 4 || int.tryParse(pin) == null) {
                  return 'Ingresa un PIN de 4 a 6 digitos';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN',
                prefixIcon: Icon(Icons.pin),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim() != _pinController.text.trim()) {
                  return 'Los PIN no coinciden';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Activar bloqueo'),
            ),
          ],
        ),
      ),
    );
  }
}
