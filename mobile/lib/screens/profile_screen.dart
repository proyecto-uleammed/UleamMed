import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/notification_scheduler.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.api,
    this.settings,
    this.permissionService,
    this.notificationScheduler,
  });

  final UleamMedApi api;
  final AppSettingsController? settings;
  final PermissionService? permissionService;
  final NotificationScheduler? notificationScheduler;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _bloodTypeController = TextEditingController();
  final _conditionsController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _notesController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  late Future<_ProfileData> _profileData = _loadProfileData();
  bool _isSaving = false;
  bool _didHydrateForm = false;
  bool _shareWithCaregivers = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _bloodTypeController.dispose();
    _conditionsController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<_ProfileData> _loadProfileData() async {
    final session = await widget.api.loadAppSession();
    final medicalProfile = await widget.api.loadMedicalProfile();
    return _ProfileData(session: session, medicalProfile: medicalProfile);
  }

  void _hydrateForm(_ProfileData data) {
    if (_didHydrateForm) {
      return;
    }
    final profile = data.medicalProfile;
    _nameController.text = data.session.user.fullName;
    _birthDateController.text = profile.birthDate;
    _bloodTypeController.text = profile.bloodType;
    _conditionsController.text = profile.conditions;
    _allergiesController.text = profile.allergies;
    _notesController.text = profile.importantNotes;
    _emergencyNameController.text = profile.emergencyContactName;
    _emergencyPhoneController.text = profile.emergencyContactPhone;
    _shareWithCaregivers = profile.shareWithCaregivers;
    _didHydrateForm = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updatedSession = await widget.api.updateProfile(
        fullName: _nameController.text.trim(),
      );
      final updatedProfile = await widget.api.saveMedicalProfile(
        MedicalProfile(
          birthDate: _birthDateController.text.trim(),
          bloodType: _bloodTypeController.text.trim(),
          conditions: _conditionsController.text.trim(),
          allergies: _allergiesController.text.trim(),
          importantNotes: _notesController.text.trim(),
          emergencyContactName: _emergencyNameController.text.trim(),
          emergencyContactPhone: _emergencyPhoneController.text.trim(),
          shareWithCaregivers: _shareWithCaregivers,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileData = Future.value(
          _ProfileData(session: updatedSession, medicalProfile: updatedProfile),
        );
        _didHydrateForm = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil medico guardado')));
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
        _error = 'No se pudo guardar el perfil';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          if (widget.settings != null)
            IconButton(
              tooltip: 'Ajustes y accesibilidad',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      settings: widget.settings!,
                      api: widget.api,
                      permissionService: widget.permissionService,
                      notificationScheduler: widget.notificationScheduler,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
            ),
          IconButton(
            tooltip: 'Guardar perfil medico',
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_ProfileData>(
          future: _profileData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return _ProfileError(
                onRetry: () {
                  setState(() {
                    _profileData = _loadProfileData();
                    _didHydrateForm = false;
                  });
                },
              );
            }

            final data = snapshot.data!;
            _hydrateForm(data);

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ProfileHeader(data: data),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    icon: Icons.person,
                    title: 'Datos del paciente',
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _nameController,
                    label: 'Nombre completo',
                    icon: Icons.person,
                    validator: (value) {
                      if ((value ?? '').trim().length < 3) {
                        return 'Ingresa tu nombre';
                      }
                      return null;
                    },
                  ),
                  _TextField(
                    initialValue: data.session.user.email,
                    label: 'Correo electronico',
                    icon: Icons.email,
                    enabled: false,
                  ),
                  _TextField(
                    controller: _birthDateController,
                    label: 'Fecha de nacimiento',
                    icon: Icons.cake,
                    hint: 'Ej. 12/03/1954',
                  ),
                  _TextField(
                    controller: _bloodTypeController,
                    label: 'Tipo de sangre',
                    icon: Icons.bloodtype,
                    hint: 'Ej. O+',
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.medical_information,
                    title: 'Informacion medica',
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _conditionsController,
                    label: 'Enfermedades o condiciones',
                    icon: Icons.monitor_heart,
                    maxLines: 3,
                    hint: 'Diabetes, hipertension, asma...',
                  ),
                  _TextField(
                    controller: _allergiesController,
                    label: 'Alergias',
                    icon: Icons.warning_amber,
                    maxLines: 3,
                    hint: 'Medicamentos, alimentos u otras alergias',
                  ),
                  _TextField(
                    controller: _notesController,
                    label: 'Indicaciones importantes',
                    icon: Icons.notes,
                    maxLines: 4,
                    hint: 'Datos que un cuidador o medico debe saber',
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.emergency,
                    title: 'Contacto de emergencia',
                  ),
                  const SizedBox(height: 12),
                  _TextField(
                    controller: _emergencyNameController,
                    label: 'Nombre del contacto',
                    icon: Icons.contact_phone,
                  ),
                  _TextField(
                    controller: _emergencyPhoneController,
                    label: 'Telefono',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Compartir con cuidadores autorizados',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    subtitle: const Text(
                      'Autorizas a tus cuidadores a ver la informacion que elijas compartir.',
                    ),
                    value: _shareWithCaregivers,
                    onChanged: (value) {
                      setState(() {
                        _shareWithCaregivers = value;
                      });
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Guardar perfil medico'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.session, required this.medicalProfile});

  final AppSession session;
  final MedicalProfile medicalProfile;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.data});

  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_circle, color: AppColors.primary, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.session.user.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  data.session.user.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
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
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ],
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.label,
    required this.icon,
    this.controller,
    this.initialValue,
    this.enabled = true,
    this.maxLines = 1,
    this.hint,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final IconData icon;
  final bool enabled;
  final int maxLines;
  final String? hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textInputAction: maxLines == 1 ? TextInputAction.next : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        validator: validator,
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
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

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 54, color: AppColors.primaryDark),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el perfil',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
