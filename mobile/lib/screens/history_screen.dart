import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

/// Historial de tomas y cumplimiento semanal (PB-029/030/032).
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late Future<List<DoseConfirmation>> _confirmations = _api
      .listDoseConfirmations();

  DoseStatus? _statusFilter;
  String? _medicationFilter;

  void _reload() {
    setState(() {
      _confirmations = _api.listDoseConfirmations();
    });
  }

  void _clearFilters() {
    setState(() {
      _statusFilter = null;
      _medicationFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<DoseConfirmation>>(
        future: _confirmations,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Cargando historial...');
          }
          if (snapshot.hasError) {
            return ErrorStateView(
              title: 'No se pudo cargar el historial',
              onRetry: _reload,
            );
          }

          final all = snapshot.data ?? const [];
          if (all.isEmpty) {
            return const EmptyStateView(
              icon: Icons.history,
              title: 'Aun no hay registros',
              message:
                  'Cuando confirmes una toma como tomada, omitida o pospuesta '
                  'aparecera aqui.',
            );
          }

          final medications = <String>{
            for (final item in all) item.medicationName,
          }.toList()..sort();

          final filtered = all.where((item) {
            final statusOk =
                _statusFilter == null || item.status == _statusFilter;
            final medicationOk =
                _medicationFilter == null ||
                item.medicationName == _medicationFilter;
            return statusOk && medicationOk;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _WeeklyComplianceCard(confirmations: all),
              const SizedBox(height: 16),
              _Filters(
                statusFilter: _statusFilter,
                medicationFilter: _medicationFilter,
                medications: medications,
                onStatusChanged: (status) {
                  setState(() => _statusFilter = status);
                },
                onMedicationChanged: (medication) {
                  setState(() => _medicationFilter = medication);
                },
                onClear: _clearFilters,
              ),
              const SizedBox(height: 12),
              Text(
                '${filtered.length} de ${all.length} registros',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: EmptyStateView(
                    icon: Icons.filter_alt_off,
                    title: 'Sin resultados con estos filtros',
                    message: 'Prueba limpiar los filtros para ver todo.',
                  ),
                )
              else
                ..._buildGroupedByDate(context, filtered),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedByDate(
    BuildContext context,
    List<DoseConfirmation> items,
  ) {
    final sorted = [...items]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    final widgets = <Widget>[];
    String? currentDay;
    for (final item in sorted) {
      final dayKey = _dayLabel(item.recordedAt);
      if (dayKey != currentDay) {
        currentDay = dayKey;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              dayKey,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        );
      }
      widgets.add(_HistoryTile(confirmation: item));
    }
    return widgets;
  }

  String _dayLabel(DateTime date) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _WeeklyComplianceCard extends StatelessWidget {
  const _WeeklyComplianceCard({required this.confirmations});

  final List<DoseConfirmation> confirmations;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final week = confirmations
        .where((item) => item.recordedAt.isAfter(weekAgo))
        .toList();

    final taken = week.where((i) => i.status == DoseStatus.taken).length;
    final omitted = week.where((i) => i.status == DoseStatus.omitted).length;
    final postponed = week
        .where((i) => i.status == DoseStatus.postponed)
        .length;
    final total = week.length;
    final percent = total == 0 ? 0 : ((taken / total) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cumplimiento de la semana',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Cumplimiento semanal $percent por ciento',
                child: SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : taken / total,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(
                            Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _MetricRow(label: 'Tomados', value: taken),
                    const SizedBox(height: 6),
                    _MetricRow(label: 'Pospuestos', value: postponed),
                    const SizedBox(height: 6),
                    _MetricRow(label: 'Omitidos', value: omitted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _motivation(percent, total),
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _motivation(int percent, int total) {
    if (total == 0) {
      return 'Aun no hay tomas esta semana. Cada registro ayuda a tu salud.';
    }
    if (percent >= 80) {
      return 'Excelente constancia esta semana. Sigue asi.';
    }
    if (percent >= 50) {
      return 'Vas por buen camino. Un pequeno esfuerzo mas ayuda mucho.';
    }
    return 'Cada toma cuenta. Manana es una nueva oportunidad.';
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.statusFilter,
    required this.medicationFilter,
    required this.medications,
    required this.onStatusChanged,
    required this.onMedicationChanged,
    required this.onClear,
  });

  final DoseStatus? statusFilter;
  final String? medicationFilter;
  final List<String> medications;
  final ValueChanged<DoseStatus?> onStatusChanged;
  final ValueChanged<String?> onMedicationChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasFilters = statusFilter != null || medicationFilter != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Filtros',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (hasFilters)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('Limpiar'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Tomados'),
              selected: statusFilter == DoseStatus.taken,
              onSelected: (selected) =>
                  onStatusChanged(selected ? DoseStatus.taken : null),
            ),
            FilterChip(
              label: const Text('Pospuestos'),
              selected: statusFilter == DoseStatus.postponed,
              onSelected: (selected) =>
                  onStatusChanged(selected ? DoseStatus.postponed : null),
            ),
            FilterChip(
              label: const Text('Omitidos'),
              selected: statusFilter == DoseStatus.omitted,
              onSelected: (selected) =>
                  onStatusChanged(selected ? DoseStatus.omitted : null),
            ),
          ],
        ),
        if (medications.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: medicationFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Medicamento',
              prefixIcon: Icon(Icons.medication),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos los medicamentos'),
              ),
              ...medications.map(
                (name) => DropdownMenuItem<String?>(
                  value: name,
                  child: Text(name),
                ),
              ),
            ],
            onChanged: onMedicationChanged,
          ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.confirmation});

  final DoseConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _statusStyle(confirmation.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(
          confirmation.medicationName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('$label - ${_time(confirmation.recordedAt)}'),
      ),
    );
  }

  (Color, IconData, String) _statusStyle(DoseStatus status) {
    switch (status) {
      case DoseStatus.taken:
        return (const Color(0xFF2E7D32), Icons.check_circle, 'Tomado');
      case DoseStatus.omitted:
        return (const Color(0xFFC62828), Icons.cancel, 'Omitido');
      case DoseStatus.postponed:
        return (const Color(0xFFF57F17), Icons.snooze, 'Pospuesto');
    }
  }

  String _time(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
