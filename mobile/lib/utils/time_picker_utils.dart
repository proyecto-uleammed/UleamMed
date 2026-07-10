import 'package:flutter/material.dart';

const _locale = Locale('es', 'ES');

/// Selector de hora en español, formato 24 h y con scroll para evitar overflow.
Future<TimeOfDay?> showSpanishTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String helpText = 'Seleccionar hora',
}) {
  return showTimePicker(
    context: context,
    locale: _locale,
    initialTime: initialTime,
    helpText: helpText,
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
    builder: (context, child) {
      final mediaQuery = MediaQuery.of(context);
      return MediaQuery(
        data: mediaQuery.copyWith(
          alwaysUse24HourFormat: true,
          textScaler: TextScaler.linear(
            mediaQuery.textScaler.scale(1).clamp(1.0, 1.3),
          ),
        ),
        child: child == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(child: child),
      );
    },
  );
}

/// Selector de fecha de nacimiento (sin fechas futuras).
Future<DateTime?> showBirthDatePicker({
  required BuildContext context,
  DateTime? initialDate,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var selected = initialDate ?? DateTime(now.year - 40, now.month, now.day);
  if (selected.isAfter(today)) {
    selected = today;
  }
  if (selected.year < 1900) {
    selected = DateTime(1900, selected.month, selected.day);
  }
  return showDatePicker(
    context: context,
    locale: _locale,
    initialDate: selected,
    firstDate: DateTime(1900),
    lastDate: today,
    helpText: 'Fecha de nacimiento',
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
}

String formatBirthDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

DateTime? parseBirthDate(String value) {
  final typed = value.trim();
  if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(typed)) {
    return null;
  }
  final parts = typed.split('/');
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) {
    return null;
  }
  return DateTime(year, month, day);
}

const bloodTypeOptions = <String>[
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
];
