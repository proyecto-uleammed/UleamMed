import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/app_states.dart';
import 'caregiver_patient_medications_screen.dart';

class CaregiverPatientsScreen extends StatefulWidget {
  const CaregiverPatientsScreen({super.key, required this.api});

  final UleamMedApi api;

  @override
  State<CaregiverPatientsScreen> createState() =>
      _CaregiverPatientsScreenState();
}

class _CaregiverPatientsScreenState extends State<CaregiverPatientsScreen> {
  late Future<_CaregiverOverview> _overview = _load();

  Future<_CaregiverOverview> _load() async {
    final results = await Future.wait([
      widget.api.listCaregivingLinks(),
      widget.api.listCaregiverPatients(),
    ]);
    return _CaregiverOverview(
      links: results[0] as List<CaregiverLink>,
      patients: results[1] as List<CaregiverPatient>,
    );
  }

  void _reload() {
    setState(() {
      _overview = _load();
    });
  }

  Future<void> _linkPatient() async {
    final linked = await showDialog<bool>(
      context: context,
      builder: (_) => _RedeemCodeDialog(api: widget.api),
    );
    if (linked == true && mounted) {
      _reload();
      showAppSnackBar(context, 'Solicitud enviada al paciente');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas a cargo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'link-patient',
        onPressed: _linkPatient,
        icon: const Icon(Icons.link),
        label: const Text('Vincular paciente'),
      ),
      body: FutureBuilder<_CaregiverOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }
          final overview = snapshot.data ?? const _CaregiverOverview();
          final pending = overview.links
              .where((link) => link.status == CaregiverLinkStatus.pending)
              .toList();
          if (overview.patients.isEmpty && pending.isEmpty) {
            return const EmptyStateView(
              icon: Icons.family_restroom,
              title: 'Aún no cuidas a ningún paciente',
              message:
                  'Solicita el código del paciente para enviarle una solicitud.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (pending.isNotEmpty) ...[
                  Text(
                    'Esperando aprobación',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  ...pending.map(
                    (link) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_top),
                        title: Text(link.counterpartName),
                        subtitle: const Text(
                          'El paciente debe aprobar tu solicitud.',
                        ),
                        trailing: const Chip(label: Text('Pendiente')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (overview.patients.isNotEmpty) ...[
                  Text(
                    'Pacientes vinculados',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  ...overview.patients.map(
                    (patient) => Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(patient.fullName),
                        subtitle: const Text('Gestionar medicamentos'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CaregiverPatientMedicationsScreen(
                              api: widget.api,
                              patient: patient,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaregiverOverview {
  const _CaregiverOverview({this.links = const [], this.patients = const []});

  final List<CaregiverLink> links;
  final List<CaregiverPatient> patients;
}

class _RedeemCodeDialog extends StatefulWidget {
  const _RedeemCodeDialog({required this.api});

  final UleamMedApi api;

  @override
  State<_RedeemCodeDialog> createState() => _RedeemCodeDialogState();
}

class _RedeemCodeDialogState extends State<_RedeemCodeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.redeemCaregiverInvitation(_controller.text);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vincular paciente'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de 8 caracteres',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final normalized = (value ?? '')
                    .replaceAll('-', '')
                    .replaceAll(' ', '');
                if (normalized.length != 8) {
                  return 'Ingresa el código completo';
                }
                return null;
              },
              onFieldSubmitted: (_) => _loading ? null : _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}
