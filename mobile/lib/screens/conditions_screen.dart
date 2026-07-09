import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

/// Enfermedades, condiciones y alergias con nivel de severidad
/// (PB-033/034/035/036).
class ConditionsScreen extends StatefulWidget {
  const ConditionsScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<ConditionsScreen> createState() => _ConditionsScreenState();
}

class _ConditionsScreenState extends State<ConditionsScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<HealthEntry>> _entries = _api.listHealthEntries();

  void _reload() {
    setState(() {
      _entries = _api.listHealthEntries();
    });
  }

  Future<void> _openForm(HealthEntryKind kind, [HealthEntry? entry]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _HealthEntryForm(
        kind: kind,
        entry: entry,
        onSave: (item) => _api.saveHealthEntry(item),
        onDelete: entry == null ? null : () => _api.deleteHealthEntry(entry.id),
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
      appBar: AppBar(title: const Text('Condiciones y alergias')),
      body: FutureBuilder<List<HealthEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }

          final entries = snapshot.data ?? const [];
          final conditions = entries
              .where((e) => e.kind == HealthEntryKind.condition)
              .toList();
          final allergies = entries
              .where((e) => e.kind == HealthEntryKind.allergy)
              .toList();
          final severeAllergies = allergies
              .where((e) => e.isSevereAllergy)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
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
                _InlineEmpty(
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
                _InlineEmpty(text: 'Aun no registras alergias.')
              else
                ...allergies.map(
                  (entry) => _HealthCard(
                    entry: entry,
                    onEdit: () => _openForm(entry.kind, entry),
                  ),
                ),
            ],
          );
        },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                IconButton(
                  tooltip: 'Editar',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: color),
                      const SizedBox(width: 6),
                      Text(
                        entry.severity.label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!entry.active)
                  const Chip(
                    label: Text('Inactiva'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (entry.date.isNotEmpty)
                  Text(
                    entry.date,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
            if (entry.detail.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(entry.detail, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
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

  bool get _isAllergy => widget.kind == HealthEntryKind.allergy;

  @override
  void dispose() {
    _nameController.dispose();
    _detailController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
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
    await widget.onSave(entry);
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
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Este campo es obligatorio'
                  : null,
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
              decoration: InputDecoration(
                labelText: _isAllergy ? 'Reaccion / notas' : 'Notas',
                prefixIcon: const Icon(Icons.notes),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Fecha aproximada (opcional)',
                hintText: 'Ej. 2020 o Marzo 2021',
                prefixIcon: Icon(Icons.event),
                border: OutlineInputBorder(),
              ),
            ),
            if (!_isAllergy)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Condicion activa'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
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
