import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

class _SyncCategory {
  const _SyncCategory({
    required this.label,
    required this.icon,
    required this.total,
    required this.pending,
  });

  final String label;
  final IconData icon;
  final int total;
  final int pending;
}

/// Cola de cambios pendientes de sincronizacion con reintento (PB-051).
class PendingSyncScreen extends StatefulWidget {
  const PendingSyncScreen({super.key, this.api, this.connectivity});

  final UleamMedApi? api;
  final ConnectivityService? connectivity;

  @override
  State<PendingSyncScreen> createState() => _PendingSyncScreenState();
}

class _PendingSyncScreenState extends State<PendingSyncScreen> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late final ConnectivityService _connectivity =
      widget.connectivity ?? ConnectivityService();
  late Future<List<_SyncCategory>> _future = _load();
  bool _retrying = false;

  Future<List<_SyncCategory>> _load() async {
    Future<List<T>> safe<T>(Future<List<T>> Function() action) async {
      try {
        return await action();
      } catch (_) {
        return <T>[];
      }
    }

    final medications = await safe(_api.listMedications);
    final doses = await safe(_api.listDoseConfirmations);
    final appointments = await safe(_api.listAppointments);
    final contacts = await safe(_api.listEmergencyContacts);
    final health = await safe(_api.listHealthEntries);
    final caregivers = await safe(_api.listCaregivers);

    return [
      _SyncCategory(
        label: 'Medicamentos',
        icon: Icons.medication,
        total: medications.length,
        pending: medications
            .where((m) => m.syncStatus == SyncStatus.pending)
            .length,
      ),
      _SyncCategory(
        label: 'Tomas registradas',
        icon: Icons.check_circle,
        total: doses.length,
        pending: doses
            .where((d) => d.syncStatus == SyncStatus.pending)
            .length,
      ),
      _SyncCategory(
        label: 'Consultas',
        icon: Icons.event,
        total: appointments.length,
        pending: appointments
            .where((a) => a.syncStatus == SyncStatus.pending)
            .length,
      ),
      _SyncCategory(
        label: 'Contactos de emergencia',
        icon: Icons.contact_phone,
        total: contacts.length,
        pending: contacts
            .where((c) => c.syncStatus == SyncStatus.pending)
            .length,
      ),
      _SyncCategory(
        label: 'Condiciones y alergias',
        icon: Icons.health_and_safety,
        total: health.length,
        pending: health
            .where((h) => h.syncStatus == SyncStatus.pending)
            .length,
      ),
      _SyncCategory(
        label: 'Cuidadores',
        icon: Icons.family_restroom,
        total: caregivers.length,
        pending: caregivers
            .where((c) => c.syncStatus == SyncStatus.pending)
            .length,
      ),
    ];
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final status = await _connectivity.currentStatus();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) {
      return;
    }
    setState(() {
      _retrying = false;
      _future = _load();
    });
    if (status == NetworkStatus.offline) {
      showAppSnackBar(
        context,
        'Sin conexion. Se reintentara cuando vuelva el internet.',
        isError: true,
      );
    } else {
      showAppSnackBar(context, 'Datos revisados. Se mantienen guardados localmente.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizacion')),
      body: FutureBuilder<List<_SyncCategory>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          final categories = snapshot.data ?? const [];
          final totalPending = categories.fold<int>(
            0,
            (sum, category) => sum + category.pending,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(totalPending: totalPending),
              const SizedBox(height: 16),
              ...categories.map((category) => _CategoryTile(category: category)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _retrying ? null : _retry,
                icon: _retrying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_retrying ? 'Revisando...' : 'Reintentar ahora'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalPending});

  final int totalPending;

  @override
  Widget build(BuildContext context) {
    final synced = totalPending == 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: synced ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            synced ? Icons.cloud_done : Icons.cloud_sync,
            size: 40,
            color: synced ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  synced
                      ? 'Todo guardado localmente'
                      : '$totalPending cambios por sincronizar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  synced
                      ? 'No hay cambios pendientes.'
                      : 'Se enviaran automaticamente cuando haya conexion.',
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final _SyncCategory category;

  @override
  Widget build(BuildContext context) {
    final hasPending = category.pending > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(category.icon, color: AppColors.primary),
        title: Text(category.label),
        subtitle: Text('${category.total} en total'),
        trailing: hasPending
            ? Chip(
                label: Text('${category.pending} pendiente(s)'),
                backgroundColor: const Color(0xFFFFF3E0),
                avatar: const Icon(Icons.sync_problem, size: 18),
              )
            : const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
      ),
    );
  }
}
