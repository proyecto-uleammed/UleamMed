import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<_MedicationData> _data = _loadData();
  final Set<String> _savingIds = {};

  Future<_MedicationData> _loadData() async {
    final medications = await _api.listMedications();
    final confirmations = await _api.listDoseConfirmations();
    final pendingSync = await _api.pendingSyncCount();
    return _MedicationData(
      medications: medications,
      confirmations: confirmations,
      pendingSync: pendingSync,
    );
  }

  void _reload() {
    setState(() {
      _data = _loadData();
    });
  }

  Future<void> _recordStatus(
    MedicationItem medication,
    DoseStatus status,
  ) async {
    if (_savingIds.contains(medication.id)) {
      return;
    }

    setState(() {
      _savingIds.add(medication.id);
    });

    try {
      await _api.recordMedicationStatus(medication.id, status);
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_statusMessage(medication.name, status)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo registrar la toma'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingIds.remove(medication.id);
        });
      }
    }
  }

  Future<void> _openMedicationForm([MedicationItem? medication]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _MedicationForm(
          medication: medication,
          onSave: (item) async {
            await _api.saveMedication(item);
          },
          onDelete: medication == null
              ? null
              : () async {
                  await _api.deleteMedication(medication.id);
                },
        );
      },
    );

    if (saved == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            medication == null
                ? 'Medicamento guardado para sincronizar'
                : 'Medicamento actualizado',
          ),
        ),
      );
    }
  }

  String _statusMessage(String name, DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return '$name marcado como tomado';
      case DoseStatus.omitted:
        return '$name marcado como omitido';
      case DoseStatus.postponed:
        return '$name pospuesto';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-medications',
        onPressed: () => _openMedicationForm(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: FutureBuilder<_MedicationData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MedicationError(onRetry: _reload);
          }

          final data = snapshot.data ?? const _MedicationData();
          final takenCount = data.medications
              .where((medication) => medication.taken)
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _MedicationSummary(
                totalCount: data.medications.length,
                takenCount: takenCount,
                pendingSync: data.pendingSync,
              ),
              const SizedBox(height: 16),
              if (data.medications.isEmpty)
                const _EmptyMedications()
              else
                ...data.medications.map(
                  (medication) => _MedicationCard(
                    medication: medication,
                    isSaving: _savingIds.contains(medication.id),
                    onEdit: () => _openMedicationForm(medication),
                    onTaken: () => _recordStatus(
                      medication,
                      DoseStatus.taken,
                    ),
                    onPostponed: () => _recordStatus(
                      medication,
                      DoseStatus.postponed,
                    ),
                    onOmitted: () => _recordStatus(
                      medication,
                      DoseStatus.omitted,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              _ConfirmationHistory(confirmations: data.confirmations),
            ],
          );
        },
      ),
    );
  }
}

class _MedicationData {
  const _MedicationData({
    this.medications = const [],
    this.confirmations = const [],
    this.pendingSync = 0,
  });

  final List<MedicationItem> medications;
  final List<DoseConfirmation> confirmations;
  final int pendingSync;
}

class _MedicationSummary extends StatelessWidget {
  const _MedicationSummary({
    required this.totalCount,
    required this.takenCount,
    required this.pendingSync,
  });

  final int totalCount;
  final int takenCount;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoy tienes $totalCount medicamentos programados.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '$takenCount ya tomados. $pendingSync cambios pendientes.',
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

class _EmptyMedications extends StatelessWidget {
  const _EmptyMedications();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.medication, color: AppColors.primary, size: 42),
          const SizedBox(height: 10),
          Text(
            'Agrega tu primer medicamento',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Se guardara en este dispositivo aunque no tengas internet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.isSaving,
    required this.onEdit,
    required this.onTaken,
    required this.onPostponed,
    required this.onOmitted,
  });

  final MedicationItem medication;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onTaken;
  final VoidCallback onPostponed;
  final VoidCallback onOmitted;

  @override
  Widget build(BuildContext context) {
    final isPending = medication.syncStatus == SyncStatus.pending;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MedicationAvatar(medication: medication),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dose} - ${medication.time}',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        '${medication.frequency} ${medication.duration.isEmpty ? '' : '- ${medication.duration}'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (medication.instructions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          medication.instructions,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: Text(
                              medication.taken ? 'Tomado' : 'Pendiente',
                            ),
                            avatar: Icon(
                              medication.taken
                                  ? Icons.check
                                  : Icons.schedule,
                              size: 18,
                            ),
                          ),
                          if (isPending)
                            const Chip(
                              label: Text('Sin sincronizar'),
                              avatar: Icon(Icons.sync_problem, size: 18),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: isSaving || medication.taken ? null : onTaken,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Tomado'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving || medication.taken ? null : onPostponed,
                  icon: const Icon(Icons.snooze),
                  label: const Text('Posponer'),
                ),
                OutlinedButton.icon(
                  onPressed: isSaving || medication.taken ? null : onOmitted,
                  icon: const Icon(Icons.close),
                  label: const Text('Omitir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationAvatar extends StatelessWidget {
  const _MedicationAvatar({required this.medication});

  final MedicationItem medication;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        medication.photoPath.isNotEmpty &&
        File(medication.photoPath).existsSync();
    if (hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(medication.photoPath),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _MedicationAvatarFallback(taken: medication.taken),
        ),
      );
    }
    return _MedicationAvatarFallback(taken: medication.taken);
  }
}

class _MedicationAvatarFallback extends StatelessWidget {
  const _MedicationAvatarFallback({required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: taken
            ? AppColors.primaryLight.withValues(alpha: 0.2)
            : AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        taken ? Icons.check_circle : Icons.medication,
        color: taken ? AppColors.primary : AppColors.textSecondary,
        size: 30,
      ),
    );
  }
}

class _ConfirmationHistory extends StatelessWidget {
  const _ConfirmationHistory({required this.confirmations});

  final List<DoseConfirmation> confirmations;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial de tomas', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        if (confirmations.isEmpty)
          Text(
            'Aun no hay confirmaciones registradas.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...confirmations.take(6).map(
                (confirmation) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _statusIcon(confirmation.status),
                    color: AppColors.primary,
                  ),
                  title: Text(confirmation.medicationName),
                  subtitle: Text(
                    '${_statusLabel(confirmation.status)} - ${_formatDate(confirmation.recordedAt)}',
                  ),
                  trailing: confirmation.syncStatus == SyncStatus.pending
                      ? const Icon(Icons.sync_problem)
                      : const Icon(Icons.cloud_done),
                ),
              ),
      ],
    );
  }

  IconData _statusIcon(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return Icons.check_circle;
      case DoseStatus.omitted:
        return Icons.cancel;
      case DoseStatus.postponed:
        return Icons.snooze;
    }
  }

  String _statusLabel(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return 'Tomado';
      case DoseStatus.omitted:
        return 'Omitido';
      case DoseStatus.postponed:
        return 'Pospuesto';
    }
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}

class _MedicationForm extends StatefulWidget {
  const _MedicationForm({
    required this.onSave,
    this.medication,
    this.onDelete,
  });

  final MedicationItem? medication;
  final Future<void> Function(MedicationItem medication) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends State<_MedicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.medication?.name ?? '',
  );
  late final _doseController = TextEditingController(
    text: widget.medication?.dose ?? '',
  );
  late final _timeController = TextEditingController(
    text: widget.medication?.time ?? '',
  );
  late final _frequencyController = TextEditingController(
    text: widget.medication?.frequency ?? 'Diario',
  );
  late final _durationController = TextEditingController(
    text: widget.medication?.duration ?? '',
  );
  late final _instructionsController = TextEditingController(
    text: widget.medication?.instructions ?? '',
  );
  late bool _isImportant = widget.medication?.isImportant ?? true;
  late String _photoPath = widget.medication?.photoPath ?? '';
  final _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _timeController.dispose();
    _frequencyController.dispose();
    _durationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 80,
      );
      if (picked == null) {
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'med_${DateTime.now().millisecondsSinceEpoch}${_extension(picked.name)}';
      final saved = await File(
        picked.path,
      ).copy('${directory.path}/$fileName');
      if (mounted) {
        setState(() => _photoPath = saved.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la foto')),
        );
      }
    }
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1) {
      return '.jpg';
    }
    return name.substring(dot);
  }

  Future<void> _choosePhotoSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galeria'),
              onTap: () {
                Navigator.pop(context);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _photoPath = '');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final now = DateTime.now();
    final id = widget.medication?.id ?? _slug(_nameController.text, now);
    final item = MedicationItem(
      id: id,
      name: _nameController.text.trim(),
      dose: _doseController.text.trim(),
      time: _timeController.text.trim(),
      taken: widget.medication?.taken ?? false,
      frequency: _frequencyController.text.trim(),
      duration: _durationController.text.trim(),
      instructions: _instructionsController.text.trim(),
      isImportant: _isImportant,
      syncStatus: SyncStatus.pending,
      createdAt: widget.medication?.createdAt ?? now,
      updatedAt: now,
      photoPath: _photoPath,
    );
    await widget.onSave(item);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isSaving = true;
    });
    await widget.onDelete?.call();
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  String _slug(String text, DateTime now) {
    final normalized = text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return '${normalized.isEmpty ? 'medicamento' : normalized}-${now.millisecondsSinceEpoch}';
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
              widget.medication == null
                  ? 'Agregar medicamento'
                  : 'Editar medicamento',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _choosePhotoSource,
                child: Column(
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent),
                      ),
                      child: _photoPath.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                File(_photoPath),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  color: AppColors.primary,
                                  size: 34,
                                ),
                                SizedBox(height: 6),
                                Text('Foto del medicamento'),
                              ],
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _photoPath.isNotEmpty ? 'Cambiar foto' : 'Agregar foto',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _FormField(
              controller: _nameController,
              label: 'Nombre',
              icon: Icons.medication,
              validator: _required,
            ),
            _FormField(
              controller: _doseController,
              label: 'Dosis',
              icon: Icons.science,
              hint: 'Ej. 500 mg',
              validator: _required,
            ),
            _FormField(
              controller: _timeController,
              label: 'Horario',
              icon: Icons.schedule,
              hint: 'Ej. 08:00',
              validator: _required,
            ),
            _FormField(
              controller: _frequencyController,
              label: 'Frecuencia',
              icon: Icons.repeat,
              hint: 'Diario, cada 8 horas...',
            ),
            _FormField(
              controller: _durationController,
              label: 'Duracion',
              icon: Icons.calendar_today,
              hint: '7 dias, permanente...',
            ),
            _FormField(
              controller: _instructionsController,
              label: 'Instrucciones',
              icon: Icons.notes,
              maxLines: 3,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Toma importante'),
              subtitle: const Text('Puede generar alerta al cuidador en fases online.'),
              value: _isImportant,
              onChanged: (value) {
                setState(() {
                  _isImportant = value;
                });
              },
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
                label: const Text('Eliminar'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
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

class _MedicationError extends StatelessWidget {
  const _MedicationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text(
              'No se pudieron cargar los medicamentos',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Revisa los datos locales y vuelve a intentar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
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
