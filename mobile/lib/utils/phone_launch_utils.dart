import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_states.dart';

/// Muestra confirmacion e inicia una llamada telefonica.
Future<void> confirmAndCallPhone(
  BuildContext context, {
  required String rawPhone,
  String? contactName,
}) async {
  final phone = rawPhone.trim();
  if (phone.isEmpty) {
    showAppSnackBar(
      context,
      'Este contacto no tiene numero. Agrega uno para poder llamar.',
      isError: true,
    );
    return;
  }

  final label = contactName?.trim().isNotEmpty == true
      ? contactName!.trim()
      : phone;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Llamar ahora'),
      content: Text('Se iniciara una llamada a $label ($phone). Deseas continuar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.phone),
          label: const Text('Llamar'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  try {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri(scheme: 'tel', path: digits.isEmpty ? phone : digits);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      showAppSnackBar(context, 'No se pudo iniciar la llamada', isError: true);
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo iniciar la llamada', isError: true);
    }
  }
}
