import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_states.dart';

class CaregiversScreen extends StatefulWidget {
  const CaregiversScreen({super.key, required this.api});

  final UleamMedApi api;

  @override
  State<CaregiversScreen> createState() => _CaregiversScreenState();
}

class _CaregiversScreenState extends State<CaregiversScreen> {
  late Future<List<CaregiverLink>> _links = widget.api.listCaregivingLinks();
  bool _generatingCode = false;

  void _reload() {
    setState(() {
      _links = widget.api.listCaregivingLinks();
    });
  }

  Future<void> _generateCode() async {
    setState(() => _generatingCode = true);
    try {
      final invitation = await widget.api.createCaregiverInvitation();
      if (!mounted) {
        return;
      }
      await _showInvitation(invitation);
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _generatingCode = false);
      }
    }
  }

  Future<void> _showInvitation(CaregiverInvitation invitation) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Código para tu cuidador'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                invitation.code,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Válido hasta ${_formatDateTime(invitation.expiresAt)}. '
                'Solo puede usarse una vez.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Copiar código',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invitation.code));
                if (mounted) {
                  showAppSnackBar(context, 'Código copiado');
                }
              },
              icon: const Icon(Icons.copy),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await widget.api.cancelCaregiverInvitation(invitation.id);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (mounted) {
                    showAppSnackBar(context, 'Código cancelado');
                  }
                } on ApiException catch (error) {
                  if (mounted) {
                    showAppSnackBar(context, error.message, isError: true);
                  }
                }
              },
              child: const Text('Cancelar código'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Listo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approve(CaregiverLink link) async {
    await _runLinkAction(
      () => widget.api.approveCaregiverLink(link.id),
      'Cuidador aprobado',
    );
  }

  Future<void> _reject(CaregiverLink link) async {
    await _runLinkAction(
      () => widget.api.rejectCaregiverLink(link.id),
      'Solicitud rechazada',
    );
  }

  Future<void> _revoke(CaregiverLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: Text(
          '${link.counterpartName} dejará de ver tus medicamentos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runLinkAction(() async {
      await widget.api.revokeCaregiverLink(link.id);
      return link;
    }, 'Acceso revocado');
  }

  Future<void> _runLinkAction(
    Future<CaregiverLink> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) {
        return;
      }
      _reload();
      showAppSnackBar(context, successMessage);
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuidadores'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'generate-caregiver-code',
        onPressed: _generatingCode ? null : _generateCode,
        icon: _generatingCode
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.key),
        label: const Text('Generar código'),
      ),
      body: FutureBuilder<List<CaregiverLink>>(
        future: _links,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorStateView(onRetry: _reload);
          }
          final visibleLinks = (snapshot.data ?? const [])
              .where(
                (link) =>
                    link.status == CaregiverLinkStatus.pending ||
                    link.status == CaregiverLinkStatus.active,
              )
              .toList();
          if (visibleLinks.isEmpty) {
            return const EmptyStateView(
              icon: Icons.family_restroom,
              title: 'Aún no tienes cuidadores',
              message:
                  'Genera un código y compártelo con la persona que te ayudará.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Text(
                  'Personas vinculadas',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                ...visibleLinks.map(
                  (link) => _CaregiverLinkCard(
                    link: link,
                    onApprove: () => _approve(link),
                    onReject: () => _reject(link),
                    onRevoke: () => _revoke(link),
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

class _CaregiverLinkCard extends StatelessWidget {
  const _CaregiverLinkCard({
    required this.link,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  final CaregiverLink link;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final pending = link.status == CaregiverLinkStatus.pending;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        link.counterpartName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(link.counterpartEmailMasked),
                    ],
                  ),
                ),
                Chip(label: Text(pending ? 'Pendiente' : 'Activo')),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.medication_outlined, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Consulta de medicamentos')),
              ],
            ),
            const SizedBox(height: 14),
            if (pending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      child: const Text('Aprobar'),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRevoke,
                  icon: const Icon(Icons.link_off),
                  label: const Text('Revocar acceso'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month a las $hour:$minute';
}
