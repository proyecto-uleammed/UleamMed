import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

class _PermissionType {
  const _PermissionType({
    required this.label,
    required this.icon,
    required this.get,
    required this.set,
  });

  final String label;
  final IconData icon;
  final bool Function(CaregiverPermission) get;
  final CaregiverPermission Function(CaregiverPermission, bool) set;
}

final List<_PermissionType> _permissionTypes = [
  _PermissionType(
    label: 'Medicamentos',
    icon: Icons.medication,
    get: (c) => c.canViewMedications,
    set: (c, v) => c.copyWith(canViewMedications: v),
  ),
  _PermissionType(
    label: 'Consultas',
    icon: Icons.event,
    get: (c) => c.canViewAppointments,
    set: (c, v) => c.copyWith(canViewAppointments: v),
  ),
  _PermissionType(
    label: 'Condiciones y alergias',
    icon: Icons.health_and_safety,
    get: (c) => c.canViewConditions,
    set: (c, v) => c.copyWith(canViewConditions: v),
  ),
  _PermissionType(
    label: 'Datos de emergencia',
    icon: Icons.emergency,
    get: (c) => c.canViewEmergency,
    set: (c, v) => c.copyWith(canViewEmergency: v),
  ),
  _PermissionType(
    label: 'Alertas y avisos',
    icon: Icons.notifications_active,
    get: (c) => c.canReceiveAlerts,
    set: (c, v) => c.copyWith(canReceiveAlerts: v),
  ),
];

/// Cuidadores: invitacion y permisos por tipo de informacion
/// (PB-041/044/015).
class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<CaregiverPermission>> _caregivers = _api.listCaregivers();

  void _reload() {
    setState(() {
      _caregivers = _api.listCaregivers();
    });
  }

  Future<void> _openForm([CaregiverPermission? caregiver]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CaregiverForm(
        caregiver: caregiver,
        onSave: (item) => _api.saveCaregiver(item),
        onDelete: caregiver == null
            ? null
            : () => _api.deleteCaregiver(caregiver.id),
      ),
    );
    if (saved == true && mounted) {
      _reload();
      showAppSnackBar(context, 'Cambios guardados');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuidadores')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-caregivers',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar'),
      ),
      body: FutureBuilder<List<CaregiverPermission>>(
        future: _caregivers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }
          final caregivers = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _SharedSummary(caregivers: caregivers),
              const SizedBox(height: 16),
              Text(
                'Personas invitadas',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              if (caregivers.isEmpty)
                const EmptyStateView(
                  icon: Icons.family_restroom,
                  title: 'Aun no invitas cuidadores',
                  message:
                      'Invita a un familiar o cuidador y elige que informacion '
                      'puede ver.',
                )
              else
                ...caregivers.map(
                  (caregiver) => _CaregiverCard(
                    caregiver: caregiver,
                    onTap: () => _openForm(caregiver),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SharedSummary extends StatelessWidget {
  const _SharedSummary({required this.caregivers});

  final List<CaregiverPermission> caregivers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.privacy_tip, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Informacion compartida',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._permissionTypes.map((type) {
            final count = caregivers.where((c) => type.get(c)).length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(type.icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(type.label)),
                  Text(
                    count == 0 ? 'Nadie' : '$count persona(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: count == 0
                          ? AppColors.textSecondary
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  const _CaregiverCard({required this.caregiver, required this.onTap});

  final CaregiverPermission caregiver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPending = caregiver.status == 'pendiente';
    final contact = caregiver.caregiverEmail.isNotEmpty
        ? caregiver.caregiverEmail
        : caregiver.caregiverPhone;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
        title: Text(
          caregiver.caregiverName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contact),
            const SizedBox(height: 4),
            Text('${caregiver.sharedCount} tipos de informacion compartidos'),
          ],
        ),
        trailing: Chip(
          label: Text(isPending ? 'Pendiente' : 'Activo'),
          backgroundColor: isPending
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFE8F5E9),
        ),
      ),
    );
  }
}

class _CaregiverForm extends StatefulWidget {
  const _CaregiverForm({required this.onSave, this.caregiver, this.onDelete});

  final CaregiverPermission? caregiver;
  final Future<void> Function(CaregiverPermission caregiver) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_CaregiverForm> createState() => _CaregiverFormState();
}

class _CaregiverFormState extends State<_CaregiverForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.caregiver?.caregiverName ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.caregiver?.caregiverEmail ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.caregiver?.caregiverPhone ?? '',
  );
  late CaregiverPermission _draft =
      widget.caregiver ??
      const CaregiverPermission(
        id: '',
        caregiverName: '',
        caregiverEmail: '',
      );
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    if (email.isEmpty && phone.isEmpty) {
      showAppSnackBar(
        context,
        'Ingresa un correo o un telefono',
        isError: true,
      );
      return;
    }

    final shared = _permissionTypes
        .where((type) => type.get(_draft))
        .map((type) => type.label)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar informacion compartida'),
        content: Text(
          shared.isEmpty
              ? 'Este cuidador no vera ninguna informacion. Deseas continuar?'
              : 'Compartiras: ${shared.join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    final id =
        widget.caregiver?.id ??
        'cuidador-${DateTime.now().millisecondsSinceEpoch}';
    final caregiver = _draft.copyWith(
      id: id,
      caregiverName: _nameController.text.trim(),
      caregiverEmail: email,
      caregiverPhone: phone,
      status: widget.caregiver?.status ?? 'pendiente',
    );
    await widget.onSave(caregiver);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    setState(() => _isSaving = true);
    await widget.onDelete?.call();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              widget.caregiver == null ? 'Invitar cuidador' : 'Editar cuidador',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Ingresa el nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo (opcional si hay telefono)',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefono (opcional si hay correo)',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Que puede ver este cuidador',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            ..._permissionTypes.map(
              (type) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(type.icon, color: AppColors.primary),
                title: Text(type.label),
                value: type.get(_draft),
                onChanged: (value) {
                  setState(() {
                    _draft = type.set(_draft, value);
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
            if (widget.onDelete != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _delete,
                icon: const Icon(Icons.delete),
                label: const Text('Quitar cuidador'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
