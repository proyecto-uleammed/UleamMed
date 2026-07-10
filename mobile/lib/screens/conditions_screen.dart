import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/form_inputs.dart';
import '../utils/phone_launch_utils.dart';
import '../utils/time_picker_utils.dart';
import '../widgets/app_states.dart';

/// Enfermedades, condiciones y alergias con nivel de severidad
/// (PB-033/034/035/036).
class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({
    super.key,
    this.api,
    this.caregiverPatientId,
    this.title,
  });

  final UleamMedApi? api;
  final int? caregiverPatientId;
  final String? title;

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<_ConditionsData> _data = _loadData();
  bool _notShared = false;

  bool get _isCaregiverMode => widget.caregiverPatientId != null;

  Future<_ConditionsData> _loadData() async {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      try {
        final profile = await _api.loadCaregiverPatientMedicalProfile(patientId);
        final entries = await _api.listCaregiverPatientHealthEntries(patientId);
        if (mounted) {
          setState(() => _notShared = false);
        }
        return _ConditionsData(profile: profile, entries: entries);
      } on ApiException catch (error) {
        if (error.statusCode == 403) {
          if (mounted) {
            setState(() => _notShared = true);
          }
          return const _ConditionsData(entries: []);
        }
        rethrow;
      }
    }

    final entries = await _api.listHealthEntries();
    return _ConditionsData(entries: entries);
  }

  void _reload() {
    setState(() {
      _data = _loadData();
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _data = _loadData();
    });
    await _data;
  }

  Future<void> _saveEntry(HealthEntry entry) {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      return _api.saveCaregiverPatientHealthEntry(patientId, entry);
    }
    return _api.saveHealthEntry(entry);
  }

  Future<void> _deleteEntry(String entryId) {
    final patientId = widget.caregiverPatientId;
    if (patientId != null) {
      return _api.deleteCaregiverPatientHealthEntry(patientId, entryId);
    }
    return _api.deleteHealthEntry(entryId);
  }

  Future<void> _openForm(HealthEntryKind kind, [HealthEntry? entry]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _HealthEntryForm(
        kind: kind,
        entry: entry,
        onSave: _saveEntry,
        onDelete: entry == null ? null : () => _deleteEntry(entry.id),
      ),
    );

    if (saved == true && mounted) {
      _reload();
      showAppSnackBar(context, 'Guardado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Condiciones y alergias'),
      ),
      body: FutureBuilder<_ConditionsData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return RefreshableScrollView(
              onRefresh: _refresh,
              child: const ErrorStateView(),
            );
          }

          if (_notShared) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  _NotSharedBanner(),
                ],
              ),
            );
          }

          final data = snapshot.data ?? const _ConditionsData(entries: []);
          final entries = data.entries;
          final conditions = entries
              .where((e) => e.kind == HealthEntryKind.condition)
              .toList();
          final allergies = entries
              .where((e) => e.kind == HealthEntryKind.allergy)
              .toList();
          final severeAllergies = allergies
              .where((e) => e.isSevereAllergy)
              .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_isCaregiverMode && data.profile != null)
                  _SharedProfileSummary(profile: data.profile!),
                if (severeAllergies.isNotEmpty)
                  _WarningBanner(
                    message:
                        'Alergia severa registrada: '
                        '${severeAllergies.map((e) => e.name).join(', ')}.',
                  ),
                _CategoryHeader(
                  icon: Icons.monitor_heart,
                  title: 'Enfermedades y condiciones',
                  onAdd: () => _openForm(HealthEntryKind.condition),
                ),
                const SizedBox(height: 8),
                if (conditions.isEmpty)
                  const _InlineEmpty(
                    text: 'Aun no registras enfermedades o condiciones.',
                  )
                else
                  ...conditions.map(
                    (entry) => _HealthCard(
                      entry: entry,
                      onEdit: () => _openForm(entry.kind, entry),
                    ),
                  ),
                const SizedBox(height: 20),
                _CategoryHeader(
                  icon: Icons.warning_amber,
                  title: 'Alergias',
                  onAdd: () => _openForm(HealthEntryKind.allergy),
                ),
                const SizedBox(height: 8),
                if (allergies.isEmpty)
                  const _InlineEmpty(text: 'Aun no registras alergias.')
                else
                  ...allergies.map(
                    (entry) => _HealthCard(
                      entry: entry,
                      onEdit: () => _openForm(entry.kind, entry),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ConditionsData {
  const _ConditionsData({this.profile, this.entries = const []});

  final MedicalProfile? profile;
  final List<HealthEntry> entries;
}

class _NotSharedBanner extends StatelessWidget {
  const _NotSharedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.lock, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(
            'Informacion no compartida',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'El paciente aun no autoriza compartir enfermedades, alergias '
            'ni perfil medico con cuidadores.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SharedProfileSummary extends StatelessWidget {
  const _SharedProfileSummary({required this.profile});

  final MedicalProfile profile;

  @override
  Widget build(BuildContext context) {
    final items = <String>[
      if (profile.birthDate.isNotEmpty)
        'Fecha de nacimiento: ${profile.birthDate}',
      if (profile.bloodType.isNotEmpty) 'Tipo de sangre: ${profile.bloodType}',
      if (profile.conditions.isNotEmpty) 'Condiciones: ${profile.conditions}',
      if (profile.allergies.isNotEmpty) 'Alergias: ${profile.allergies}',
      if (profile.importantNotes.isNotEmpty)
        'Notas: ${profile.importantNotes}',
      if (profile.emergencyContactName.isNotEmpty)
        'Contacto: ${profile.emergencyContactName} (${profile.emergencyContactPhone})',
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_information, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Perfil medico compartido',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}

Color severityColor(SeverityLevel level) {
  switch (level) {
    case SeverityLevel.low:
      return const Color(0xFF2E7D32);
    case SeverityLevel.medium:
      return const Color(0xFFF57F17);
    case SeverityLevel.high:
      return const Color(0xFFC62828);
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC62828)),
      ),
      child: Row(
        children: [
          const Icon(Icons.report, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.icon,
    required this.title,
    required this.onAdd,
  });

  final IconData icon;
  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
        ),
        IconButton.filledTonal(
          tooltip: 'Agregar',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.entry, required this.onEdit});

  final HealthEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(entry.severity);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      entry.severity.label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (entry.date.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Desde: ${entry.date}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (entry.kind == HealthEntryKind.condition) ...[
                const SizedBox(height: 6),
                Text(
                  entry.active ? 'Activa' : 'Inactiva',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (entry.detail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(entry.detail, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthEntryForm extends StatefulWidget {
  const _HealthEntryForm({
    required this.kind,
    required this.onSave,
    this.entry,
    this.onDelete,
  });

  final HealthEntryKind kind;
  final HealthEntry? entry;
  final Future<void> Function(HealthEntry entry) onSave;
  final Future<void> Function()? onDelete;

  @override
  State<_HealthEntryForm> createState() => _HealthEntryFormState();
}

class _HealthEntryFormState extends State<_HealthEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.entry?.name ?? '',
  );
  late final _detailController = TextEditingController(
    text: widget.entry?.detail ?? '',
  );
  late final _dateController = TextEditingController(
    text: widget.entry?.date ?? '',
  );
  late SeverityLevel _severity = widget.entry?.severity ?? SeverityLevel.low;
  late bool _active = widget.entry?.active ?? true;
  bool _isSaving = false;
  String? _error;

  bool get _isAllergy => widget.kind == HealthEntryKind.allergy;

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickApproxDate() async {
    final picked = await showApproxHealthDatePicker(
      context: context,
      initialDate: parseBirthDate(_dateController.text),
    );
    if (picked != null && mounted) {
      setState(() {
        _dateController.text = formatBirthDate(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    final id =
        widget.entry?.id ??
        '${widget.kind.name}-${DateTime.now().millisecondsSinceEpoch}';
    final entry = HealthEntry(
      id: id,
      kind: widget.kind,
      name: _nameController.text.trim(),
      severity: _severity,
      detail: _detailController.text.trim(),
      date: _dateController.text.trim(),
      active: _active,
    );
    try {
      await widget.onSave(entry);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo guardar el registro';
        _isSaving = false;
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onDelete?.call();
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo eliminar el registro';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.entry == null
        ? (_isAllergy ? 'Agregar alergia' : 'Agregar condicion')
        : 'Editar';
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
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _isAllergy ? 'Alergia' : 'Nombre',
                prefixIcon: Icon(
                  _isAllergy ? Icons.warning_amber : Icons.monitor_heart,
                ),
                border: const OutlineInputBorder(),
              ),
              inputFormatters: FormInputs.personName,
              validator: FormInputs.healthEntryNameValidator,
            ),
            const SizedBox(height: 12),
            Text(
              _isAllergy ? 'Nivel de riesgo' : 'Severidad',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: SeverityLevel.values.map((level) {
                final selected = _severity == level;
                final color = severityColor(level);
                return ChoiceChip(
                  label: Text(level.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _severity = level),
                  selectedColor: color.withValues(alpha: 0.18),
                  side: BorderSide(color: color),
                  labelStyle: TextStyle(
                    color: selected ? color : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _isAllergy ? 'Reaccion / notas' : 'Notas',
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => FormInputs.optionalMultiline(
                value,
                maxLength: 500,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickApproxDate,
              decoration: InputDecoration(
                labelText: 'Fecha aproximada (opcional)',
                hintText: 'DD/MM/AAAA',
                prefixIcon: const Icon(Icons.event),
                border: const OutlineInputBorder(),
                suffixIcon: _dateController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Quitar fecha',
                        onPressed: () => setState(() => _dateController.clear()),
                        icon: const Icon(Icons.clear),
                      ),
              ),
              validator: FormInputs.optionalBirthDateValidator,
            ),
            if (!_isAllergy)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Condicion activa'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
