import 'package:flutter/material.dart';

import '../services/lock_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de desbloqueo por PIN al abrir la app o tras inactividad (PB-054).
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.onUnlocked,
    this.lockService,
  });

  final VoidCallback onUnlocked;
  final LockService? lockService;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  late final LockService _lock = widget.lockService ?? LockService();
  final _pinController = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final ok = await _lock.verifyPin(_pinController.text.trim());
    if (!mounted) {
      return;
    }
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _checking = false;
        _error = 'PIN incorrecto. Intenta de nuevo.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingresa tu PIN',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu informacion esta protegida.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 26, letterSpacing: 8),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _checking ? null : _verify,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Desbloquear'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
