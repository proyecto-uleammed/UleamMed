import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_states.dart';

/// Muestra confirmacion e inicia una llamada telefonica.
Future<void> confirmAndCallPhone(
  BuildContext context, {
  required String rawPhone,
  String? contactName,
  bool allowShortCode = false,
}) async {
  final phone = normalizeEcuadorPhoneForDialer(
    rawPhone,
    allowShortCode: allowShortCode,
  );
  if (phone == null) {
    showAppSnackBar(
      context,
      'Este contacto no tiene un numero valido.',
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
      content: Text('Se abrira el marcador para llamar a $label ($phone).'),
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
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      showAppSnackBar(context, 'No se pudo abrir el marcador', isError: true);
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, 'No se pudo abrir el marcador', isError: true);
    }
  }
}

String? normalizeEcuadorPhoneForDialer(
  String rawPhone, {
  bool allowShortCode = false,
}) {
  final trimmed = rawPhone.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (allowShortCode && digits.length >= 3 && digits.length <= 4) {
    return digits;
  }
  if (digits.isEmpty) {
    return null;
  }

  String national;
  if (trimmed.startsWith('+593') || digits.startsWith('593')) {
    national = digits.substring(3);
  } else if (digits.startsWith('0')) {
    national = digits.substring(1);
  } else {
    national = digits;
  }

  if (national.length < 8 || national.length > 9) {
    return null;
  }
  return '+593$national';
}
