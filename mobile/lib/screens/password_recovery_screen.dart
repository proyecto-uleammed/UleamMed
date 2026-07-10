import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/form_inputs.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.api});

  final UleamMedApi api;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _requestFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _codeRequested = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (!_requestFormKey.currentState!.validate()) {
      return;
    }

    await _runAction(() async {
      final message = await widget.api.requestPasswordReset(
        email: _emailController.text.trim(),
      );
      setState(() {
        _codeRequested = true;
        _message = message;
      });
    });
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) {
      return;
    }

    await _runAction(() async {
      final message = await widget.api.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      setState(() {
        _message = message;
        _error = null;
      });
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.pop(context);
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo conectar con el backend';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contrasena')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.lock_reset, color: AppColors.primary, size: 64),
            const SizedBox(height: 16),
            Text(
              'Recuperar acceso',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _codeRequested
                  ? 'Ingresa el codigo recibido y tu nueva contrasena.'
                  : 'Ingresa el correo de tu cuenta.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Form(
              key: _requestFormKey,
              child: TextFormField(
                controller: _emailController,
                enabled: !_isLoading && !_codeRequested,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                inputFormatters: FormInputs.email,
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: FormInputs.emailValidator,
                onFieldSubmitted: (_) => _isLoading ? null : _requestCode(),
              ),
            ),
            if (_codeRequested) ...[
              const SizedBox(height: 14),
              Form(
                key: _resetFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _codeController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: FormInputs.digitsOnly,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'Codigo de 6 digitos',
                        prefixIcon: Icon(Icons.pin),
                        border: OutlineInputBorder(),
                      ),
                      validator: FormInputs.recoveryCodeValidator,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Nueva contrasena',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contrasena'
                              : 'Ocultar contrasena',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: FormInputs.passwordValidator,
                      onFieldSubmitted: (_) =>
                          _isLoading ? null : _resetPassword(),
                    ),
                  ],
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              _InfoBox(message: _message!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorBox(message: _error!),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isLoading
                  ? null
                  : _codeRequested
                  ? _resetPassword
                  : _requestCode,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_codeRequested ? Icons.save : Icons.send),
              label: Text(
                _codeRequested ? 'Restablecer contrasena' : 'Solicitar codigo',
              ),
            ),
            if (_codeRequested) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _codeRequested = false;
                          _message = null;
                          _error = null;
                          _codeController.clear();
                          _passwordController.clear();
                        });
                      },
                icon: const Icon(Icons.edit),
                label: const Text('Cambiar correo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE57373)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFC62828),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
