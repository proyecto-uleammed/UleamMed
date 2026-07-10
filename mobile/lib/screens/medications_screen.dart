import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'medication_trash_screen.dart';
import '../services/api_service.dart';
import '../services/notification_scheduler.dart';
import '../theme/app_theme.dart';
import '../utils/form_inputs.dart';
import '../widgets/role_shell_scaffold.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({
    super.key,
    this.api,
    this.notificationScheduler,
    this.shellTabIndex,
  });

  final UleamMedApi? api;
  final NotificationScheduler? notificationScheduler;
  final int? shellTabIndex;

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<_MedicationData> _data = _loadData();
  final Set<String> _savingIds = {};
  int? _lastShellTabIndex;

  Future<_MedicationData> _loadData() async {
    final medications = await _api.listMedications();
    unawaited(_reconcileReminders(medications));
    final confirmations = await _api.listDoseConfirmations();
    return _MedicationData(
      medications: medications,
      confirmations: confirmations,
    );
  }

  Future<void> _reconcileReminders(List<MedicationItem> medications) async {
    try {
      await widget.notificationScheduler?.reconcile(medications);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Medicamento guardado, pero no se pudo programar la alarma',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _reload() {
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _loadData();
    });
    await _data;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shellTabIndex = widget.shellTabIndex;
    if (shellTabIndex == null) {
      return;
    }
    final activeIndex = roleShellActiveTabIndex(context);
    if (activeIndex == shellTabIndex &&
        _lastShellTabIndex != null &&
        _lastShellTabIndex != activeIndex) {
      _reload();
    }
    _lastShellTabIndex = activeIndex;
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
    final saved = await showMedicationEditorSheet(
      context,
      medication: medication,
      onSave: (item) => _api.saveMedication(item),
      onDelete: medication == null
          ? null
          : () async {
              await widget.notificationScheduler?.cancel(medication.id);
              await _api.deleteMedication(medication.id);
            },
    );

    if (saved == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            medication == null
                ? 'Medicamento guardado'
                : 'Medicamento actualizado',
          ),
        ),
      );
    }
  }

  Future<void> _deleteMedication(MedicationItem medication) async {
    if (_savingIds.contains(medication.id)) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: Text(
          'Se eliminara ${medication.name} de tu lista y se cancelaran sus alarmas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _savingIds.add(medication.id);
    });

    try {
      await widget.notificationScheduler?.cancel(medication.id);
      await _api.deleteMedication(medication.id);
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medication.name} eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar el medicamento'),
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

  String _statusMessage(String name, DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return '$name marcado como tomado';
      case DoseStatus.omitted:
        return '$name marcado como omitido';
      case DoseStatus.postponed:
        return '$name pospuesto';
      case DoseStatus.missed:
        return '$name no fue confirmado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicamentos'),
        actions: [
          IconButton(
            tooltip: 'Papelera',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => MedicationTrashScreen(api: _api),
                ),
              );
            },
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
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

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
              _MedicationSummary(
                totalCount: data.medications.length,
                takenCount: takenCount,
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
                    onDelete: () => _deleteMedication(medication),
                    onTaken: () => _recordStatus(medication, DoseStatus.taken),
                    onPostponed: () =>
                        _recordStatus(medication, DoseStatus.postponed),
                    onOmitted: () =>
                        _recordStatus(medication, DoseStatus.omitted),
                  ),
                ),
              const SizedBox(height: 20),
              _ConfirmationHistory(confirmations: data.confirmations),
            ],
            ),
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
  });

  final List<MedicationItem> medications;
  final List<DoseConfirmation> confirmations;
}

class _MedicationSummary extends StatelessWidget {
  const _MedicationSummary({
    required this.totalCount,
    required this.takenCount,
  });

  final int totalCount;
  final int takenCount;

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
                  totalCount == 0
                      ? 'Aun no tienes medicamentos programados.'
                      : 'Hoy tienes $totalCount medicamentos programados.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (totalCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$takenCount ya tomados.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
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
            'Aqui apareceran tus medicamentos con su dosis, horario y foto. '
            'Toca el boton + para agregar el primero.',
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
    required this.onDelete,
    required this.onTaken,
    required this.onPostponed,
    required this.onOmitted,
  });

  final MedicationItem medication;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTaken;
  final VoidCallback onPostponed;
  final VoidCallback onOmitted;

  @override
  Widget build(BuildContext context) {
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
                      Chip(
                        label: Text(medication.taken ? 'Tomado' : 'Pendiente'),
                        avatar: Icon(
                          medication.taken ? Icons.check : Icons.schedule,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: isSaving ? null : onEdit,
                      icon: const Icon(Icons.edit),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: isSaving ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
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
          key: ValueKey(medication.photoPath),
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
        Text(
          'Historial de tomas',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        if (confirmations.isEmpty)
          Text(
            'Aun no hay confirmaciones registradas.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...confirmations
              .take(6)
              .map(
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
      case DoseStatus.missed:
        return Icons.schedule;
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
      case DoseStatus.missed:
        return 'No confirmado';
    }
  }

  String _formatDate(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }
}

Future<bool?> showMedicationEditorSheet(
  BuildContext context, {
  MedicationItem? medication,
  required Future<void> Function(MedicationItem medication) onSave,
  Future<void> Function()? onDelete,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return _MedicationForm(
        medication: medication,
        onSave: onSave,
        onDelete: onDelete,
      );
    },
  );
}

class _MedicationForm extends StatefulWidget {
  const _MedicationForm({required this.onSave, this.medication, this.onDelete});

  final MedicationItem? medication;
  final Future<void> Function(MedicationItem medication) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_MedicationForm> createState() => _MedicationFormState();
}

enum _DurationMode { days, endDate, permanent }

class _MedicationFormState extends State<_MedicationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.medication?.name ?? '',
  );
  late final _doseController = TextEditingController(
    text:
        widget.medication?.doseAmount?.toString() ??
        _numericDose(widget.medication?.dose),
  );
  late final _instructionsController = TextEditingController(
    text: widget.medication?.instructions ?? '',
  );
  late bool _isImportant = widget.medication?.isImportant ?? true;
  late String _photoPath = widget.medication?.photoPath ?? '';
  late String _doseUnit = widget.medication?.doseUnit.isNotEmpty == true
      ? widget.medication!.doseUnit
      : 'mg';
  late MedicationScheduleMode _scheduleMode =
      widget.medication?.effectiveSchedule.mode ??
      MedicationScheduleMode.fixedTimes;
  late int _intervalHours =
      widget.medication?.effectiveSchedule.intervalHours ?? 12;
  late List<String> _times = List<String>.from(
    widget.medication?.effectiveSchedule.times ?? const ['08:00'],
  );
  late final Set<int> _weekdays = Set<int>.from(
    widget.medication?.effectiveSchedule.weekdays ??
        const [1, 2, 3, 4, 5, 6, 7],
  );
  late _DurationMode _durationMode =
      widget.medication?.effectiveSchedule.endDate == null
      ? _DurationMode.permanent
      : _DurationMode.endDate;
  late DateTime _endDate =
      widget.medication?.effectiveSchedule.endDate ??
      DateTime.now().add(const Duration(days: 7));
  int _durationDays = 7;
  final _picker = ImagePicker();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
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
      final directory = await getTemporaryDirectory();
      final fileName =
          'med_${DateTime.now().millisecondsSinceEpoch}${_extension(picked.name)}';
      final saved = await File(picked.path).copy('${directory.path}/$fileName');
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
    if (!_formKey.currentState!.validate() ||
        _weekdays.isEmpty ||
        _times.isEmpty) {
      if (_weekdays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un día')),
        );
      }
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final now = DateTime.now();
    final id = widget.medication?.id ?? _slug(_nameController.text, now);
    final amount = double.parse(
      _doseController.text.trim().replaceAll(',', '.'),
    );
    final startDate =
        widget.medication?.effectiveSchedule.startDate ??
        DateTime(now.year, now.month, now.day);
    final endDate = switch (_durationMode) {
      _DurationMode.permanent => null,
      _DurationMode.days => startDate.add(Duration(days: _durationDays - 1)),
      _DurationMode.endDate => _endDate,
    };
    final sortedTimes = List<String>.from(_times)..sort();
    final schedule = MedicationSchedule(
      mode: _scheduleMode,
      intervalHours: _scheduleMode == MedicationScheduleMode.interval
          ? _intervalHours
          : null,
      times: _scheduleMode == MedicationScheduleMode.interval
          ? [sortedTimes.first]
          : sortedTimes,
      weekdays: _weekdays.toList()..sort(),
      startDate: startDate,
      endDate: endDate,
    );
    final dose = '${_formatAmount(amount)} $_doseUnit';
    final item = MedicationItem(
      id: id,
      name: _nameController.text.trim(),
      dose: dose,
      doseAmount: amount,
      doseUnit: _doseUnit,
      time: schedule.times.first,
      taken: widget.medication?.taken ?? false,
      frequency: _scheduleMode == MedicationScheduleMode.interval
          ? 'Cada $_intervalHours horas'
          : '${schedule.times.length} veces al día',
      duration: endDate == null
          ? 'Permanente'
          : '${endDate.difference(startDate).inDays + 1} días',
      instructions: _instructionsController.text.trim(),
      isImportant: _isImportant,
      syncStatus: SyncStatus.pending,
      createdAt: widget.medication?.createdAt ?? now,
      updatedAt: now,
      photoPath: _photoPath,
      schedule: schedule,
    );
    var saved = false;
    try {
      await widget.onSave(item);
      saved = true;
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is ApiException
          ? error.message
          : 'No se pudo guardar el medicamento';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted && !saved) {
        setState(() {
          _isSaving = false;
        });
      }
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

  static String _numericDose(String? value) {
    return RegExp(
          r'\d+(?:[.,]\d+)?',
        ).firstMatch(value ?? '')?.group(0)?.replaceAll(',', '.') ??
        '';
  }

  String _formatAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  Future<void> _pickTime({int? index}) async {
    final current = index == null ? _times.first : _times[index];
    final parts = current.split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 8,
        minute: int.tryParse(parts.last) ?? 0,
      ),
      helpText: 'Selecciona la hora de la toma',
    );
    if (selected == null) {
      return;
    }
    final value =
        '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (index == null) {
        _times.add(value);
      } else {
        _times[index] = value;
      }
      _times = _times.toSet().toList()..sort();
    });
  }

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Selecciona la fecha final',
    );
    if (selected != null) {
      setState(() => _endDate = selected);
    }
  }

  String get _scheduleSummary {
    final amount = _doseController.text.trim().isEmpty
        ? 'Dosis pendiente'
        : '${_doseController.text.trim()} $_doseUnit';
    final timeText = _scheduleMode == MedicationScheduleMode.interval
        ? 'cada $_intervalHours horas desde ${_times.first}'
        : 'a las ${(List<String>.from(_times)..sort()).join(' y ')}';
    final dayText = _weekdays.length == 7
        ? 'todos los días'
        : '${_weekdays.length} días por semana';
    final durationText = switch (_durationMode) {
      _DurationMode.permanent => 'sin fecha final',
      _DurationMode.days => 'durante $_durationDays días',
      _DurationMode.endDate =>
        'hasta ${_endDate.day}/${_endDate.month}/${_endDate.year}',
    };
    return '$amount, $timeText, $dayText, $durationText.';
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
                          : const Icon(
                              Icons.add_a_photo,
                              color: AppColors.primary,
                              size: 34,
                            ),
                    ),
                    if (_photoPath.isEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Foto del medicamento',
                        textAlign: TextAlign.center,
                      ),
                    ],
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
              validator: (value) => FormInputs.requiredText(value),
            ),
            _FormField(
              controller: _doseController,
              label: 'Cantidad',
              icon: Icons.science,
              hint: 'Ej. 150',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: FormInputs.decimalQuantity,
              validator: FormInputs.positiveDecimal,
            ),
            DropdownButtonFormField<String>(
              initialValue: _doseUnit,
              decoration: const InputDecoration(
                labelText: 'Unidad',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              items:
                  const ['mg', 'g', 'mcg', 'ml', 'tableta', 'gotas', 'unidades']
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _doseUnit = value ?? 'mg'),
            ),
            const SizedBox(height: 18),
            Text('Frecuencia', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<MedicationScheduleMode>(
              segments: const [
                ButtonSegment(
                  value: MedicationScheduleMode.interval,
                  icon: Icon(Icons.repeat),
                  label: Text('Cada X horas'),
                ),
                ButtonSegment(
                  value: MedicationScheduleMode.fixedTimes,
                  icon: Icon(Icons.schedule),
                  label: Text('Horas específicas'),
                ),
              ],
              selected: {_scheduleMode},
              onSelectionChanged: (selection) {
                setState(() => _scheduleMode = selection.first);
              },
            ),
            const SizedBox(height: 14),
            if (_scheduleMode == MedicationScheduleMode.interval)
              DropdownButtonFormField<int>(
                initialValue: _intervalHours,
                decoration: const InputDecoration(
                  labelText: 'Intervalo',
                  prefixIcon: Icon(Icons.timelapse),
                  border: OutlineInputBorder(),
                ),
                items: const [2, 4, 6, 8, 12, 24]
                    .map(
                      (hours) => DropdownMenuItem(
                        value: hours,
                        child: Text('Cada $hours horas'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _intervalHours = value ?? 12);
                },
              ),
            const SizedBox(height: 12),
            Text(
              _scheduleMode == MedicationScheduleMode.interval
                  ? 'Hora inicial'
                  : 'Horas de toma',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            ..._times.asMap().entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.access_time,
                  color: AppColors.primary,
                ),
                title: Text(entry.value),
                trailing:
                    _scheduleMode == MedicationScheduleMode.fixedTimes &&
                        _times.length > 1
                    ? IconButton(
                        tooltip: 'Quitar hora',
                        onPressed: () {
                          setState(() => _times.removeAt(entry.key));
                        },
                        icon: const Icon(Icons.delete_outline),
                      )
                    : const Icon(Icons.edit),
                onTap: () => _pickTime(index: entry.key),
              ),
            ),
            if (_scheduleMode == MedicationScheduleMode.fixedTimes &&
                _times.length < 12)
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Agregar otra hora'),
              ),
            const SizedBox(height: 16),
            Text(
              'Días de la semana',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  const [
                    (1, 'Lun'),
                    (2, 'Mar'),
                    (3, 'Mié'),
                    (4, 'Jue'),
                    (5, 'Vie'),
                    (6, 'Sáb'),
                    (7, 'Dom'),
                  ].map((day) {
                    final selected = _weekdays.contains(day.$1);
                    return FilterChip(
                      label: Text(day.$2),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          selected
                              ? _weekdays.remove(day.$1)
                              : _weekdays.add(day.$1);
                        });
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 18),
            Text('Duración', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<_DurationMode>(
              segments: const [
                ButtonSegment(value: _DurationMode.days, label: Text('Días')),
                ButtonSegment(
                  value: _DurationMode.endDate,
                  label: Text('Fecha final'),
                ),
                ButtonSegment(
                  value: _DurationMode.permanent,
                  label: Text('Permanente'),
                ),
              ],
              selected: {_durationMode},
              onSelectionChanged: (selection) {
                setState(() => _durationMode = selection.first);
              },
            ),
            if (_durationMode == _DurationMode.days)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cantidad de días'),
                subtitle: Text('$_durationDays días'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Restar día',
                      onPressed: _durationDays > 1
                          ? () => setState(() => _durationDays--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      tooltip: 'Agregar día',
                      onPressed: () => setState(() => _durationDays++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            if (_durationMode == _DurationMode.endDate)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: const Text('Fecha final'),
                subtitle: Text(
                  '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                ),
                trailing: const Icon(Icons.edit_calendar),
                onTap: _pickEndDate,
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
              subtitle: const Text(
                'Puede generar alerta al cuidador en fases online.',
              ),
              value: _isImportant,
              onChanged: (value) {
                setState(() {
                  _isImportant = value;
                });
              },
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _scheduleSummary,
                style: Theme.of(context).textTheme.bodyLarge,
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
                label: const Text('Eliminar'),
              ),
            ],
          ],
        ),
      ),
    );
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
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
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
