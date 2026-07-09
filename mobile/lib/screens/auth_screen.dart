import 'package:flutter/material.dart';

import '../models/app_role.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'legal_screen.dart';
import 'password_recovery_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final UleamMedApi api;
  final ValueChanged<AppSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  AppRole _registrationRole = AppRole.patient;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isRegisterMode && !_acceptedTerms) {
      setState(() {
        _error = 'Debes aceptar los terminos para crear tu cuenta';
      });
      return;
    }

    await _runAuthAction(() {
      if (_isRegisterMode) {
        return widget.api.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          accountType: _registrationRole,
        );
      }

      return widget.api.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    });
  }

  Future<void> _runAuthAction(Future<AppSession> Function() action) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await action();
      if (!mounted) {
        return;
      }
      widget.onAuthenticated(session);
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

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.health_and_safety,
              color: AppColors.primary,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'UleamMed',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _isRegisterMode
                  ? _registrationRole == AppRole.caregiver
                        ? 'Crear cuenta de cuidador'
                        : 'Crear cuenta de paciente'
                  : 'Iniciar sesión',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 28),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!_isRegisterMode) {
                          return null;
                        }
                        if ((value ?? '').trim().length < 3) {
                          return 'Ingresa tu nombre';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tipo de cuenta',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppRole>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: AppRole.patient,
                            icon: Icon(Icons.person),
                            label: Text('Paciente'),
                          ),
                          ButtonSegment(
                            value: AppRole.caregiver,
                            icon: Icon(Icons.family_restroom),
                            label: Text('Cuidador'),
                          ),
                        ],
                        selected: {_registrationRole},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _registrationRole = selection.first;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = (value ?? '').trim();
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
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
                    validator: (value) {
                      if ((value ?? '').length < 8) {
                        return 'Mínimo 8 caracteres';
                      }
                      return null;
                    },
                    onChanged: (_) {
                      if (_isRegisterMode) {
                        setState(() {});
                      }
                    },
                    onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                  ),
                  if (_isRegisterMode) ...[
                    const SizedBox(height: 12),
                    _PasswordRequirements(password: _passwordController.text),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!_isRegisterMode) {
                          return null;
                        }
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _acceptedTerms,
                      onChanged: (value) {
                        setState(() => _acceptedTerms = value ?? false);
                      },
                      title: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Acepto los '),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const LegalScreen(showAccept: false),
                              ),
                            ),
                            child: const Text(
                              'terminos y privacidad',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE57373)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isRegisterMode ? Icons.person_add : Icons.login),
              label: Text(_isRegisterMode ? 'Crear cuenta' : 'Entrar'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _toggleMode,
              icon: Icon(_isRegisterMode ? Icons.login : Icons.person_add),
              label: Text(
                _isRegisterMode
                    ? 'Ya tengo cuenta'
                    : 'Necesito crear una cuenta',
              ),
            ),
            if (!_isRegisterMode) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PasswordRecoveryScreen(api: widget.api),
                        ),
                      ),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Olvide mi contrasena'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final hasLength = password.length >= 8;
    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementRow(ok: hasLength, text: 'Al menos 8 caracteres'),
        _RequirementRow(ok: hasLetter, text: 'Incluye una letra'),
        _RequirementRow(ok: hasNumber, text: 'Incluye un numero'),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF2E7D32) : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
