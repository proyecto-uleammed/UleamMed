import 'package:flutter/services.dart';

/// Formatos y validaciones reutilizables para formularios de la app.
abstract final class FormInputs {
  static final decimalQuantity = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
    const _SingleDecimalSeparatorFormatter(),
  ];

  static final digitsOnly = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
  ];

  static final phone = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s()-]')),
    LengthLimitingTextInputFormatter(20),
  ];

  static final caregiverCode = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
    LengthLimitingTextInputFormatter(9),
    const _UpperCaseTextFormatter(),
  ];

  static final bloodType = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[ABOabo+-]')),
    LengthLimitingTextInputFormatter(3),
  ];

  static final birthDate = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
    LengthLimitingTextInputFormatter(10),
  ];

  static final personName = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(
      RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'.-]"),
    ),
    LengthLimitingTextInputFormatter(80),
  ];

  static final email = <TextInputFormatter>[
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
    LengthLimitingTextInputFormatter(120),
  ];

  static String? requiredText(String? value, {String message = 'Campo requerido'}) {
    if ((value ?? '').trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? personNameValidator(String? value, {bool required = true}) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return required ? 'Ingresa el nombre' : null;
    }
    if (trimmed.length < 3) {
      return 'Mínimo 3 caracteres';
    }
    if (!RegExp(r"^[\p{L}\s'.-]+$", unicode: true).hasMatch(trimmed)) {
      return 'Solo letras y espacios';
    }
    return null;
  }

  static String? emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'Ingresa tu correo';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  static String? passwordValidator(String? value, {int minLength = 8}) {
    final password = value ?? '';
    if (password.length < minLength) {
      return 'Mínimo $minLength caracteres';
    }
    return null;
  }

  static String? positiveDecimal(String? value) {
    final normalized = (value ?? '').trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return 'Ingresa la cantidad';
    }
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) {
      return 'Solo números';
    }
    final amount = double.tryParse(normalized);
    if (amount == null || amount <= 0) {
      return 'Ingresa un número mayor a 0';
    }
    return null;
  }

  static String? phoneValidator(String? value, {bool required = true}) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return required ? 'Ingresa un teléfono' : null;
    }
    if (digits.length < 7 || digits.length > 15) {
      return 'Teléfono inválido';
    }
    return null;
  }

  static String? bloodTypeValidator(String? value) {
    final typed = (value ?? '').trim().toUpperCase();
    if (typed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^(A|B|AB|O)[+-]$').hasMatch(typed)) {
      return 'Ejemplo válido: O+ o AB-';
    }
    return null;
  }

  static String? birthDateValidator(String? value) {
    final typed = (value ?? '').trim();
    if (typed.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(typed)) {
      return 'Usa el formato DD/MM/AAAA';
    }
    final parts = typed.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return 'Fecha inválida';
    }
    if (month < 1 || month > 12 || day < 1 || day > 31 || year < 1900) {
      return 'Fecha inválida';
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return 'Fecha inválida';
    }
    final today = DateTime.now();
    if (parsed.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'La fecha no puede ser futura';
    }
    return null;
  }

  static String? optionalMultiline(String? value, {int maxLength = 1000}) {
    final typed = (value ?? '').trim();
    if (typed.isEmpty) {
      return null;
    }
    if (typed.length > maxLength) {
      return 'Máximo $maxLength caracteres';
    }
    return null;
  }

  static String? healthEntryNameValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Este campo es obligatorio';
    }
    if (trimmed.length < 3) {
      return 'Mínimo 3 caracteres';
    }
    if (!RegExp(r"^[\p{L}\s'.-]+$", unicode: true).hasMatch(trimmed)) {
      return 'Solo letras y espacios';
    }
    return null;
  }

  static String? approxDateValidator(String? value) {
    final typed = (value ?? '').trim();
    if (typed.isEmpty) {
      return null;
    }
    if (typed.length > 30) {
      return 'Máximo 30 caracteres';
    }
    if (!RegExp(r'^[0-9A-Za-záéíóúÁÉÍÓÚñÑüÜ\s./-]+$').hasMatch(typed)) {
      return 'Fecha aproximada inválida';
    }
    return null;
  }

  static String? pairedEmergencyContactValidator({
    required String? name,
    required String? phone,
  }) {
    final contactName = (name ?? '').trim();
    final contactPhone = (phone ?? '').trim();
    if (contactName.isEmpty && contactPhone.isEmpty) {
      return null;
    }
    if (contactName.isNotEmpty && contactPhone.isEmpty) {
      return 'Ingresa el teléfono del contacto';
    }
    if (contactPhone.isNotEmpty && contactName.isEmpty) {
      return 'Ingresa el nombre del contacto';
    }
    return null;
  }

  static String? optionalBirthDateValidator(String? value) {
    final typed = (value ?? '').trim();
    if (typed.isEmpty) {
      return null;
    }
    return birthDateValidator(value);
  }

  static String? caregiverCodeValidator(String? value) {
    final normalized = (value ?? '')
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .toUpperCase();
    if (normalized.length != 8) {
      return 'Ingresa el código completo';
    }
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
      return 'Solo letras y números';
    }
    return null;
  }

  static String? recoveryCodeValidator(String? value) {
    final code = (value ?? '').trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      return 'Ingresa el código de 6 dígitos';
    }
    return null;
  }

  static String? pinValidator(String? value) {
    final pin = (value ?? '').trim();
    if (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null) {
      return 'Ingresa un PIN de 4 a 6 dígitos';
    }
    return null;
  }
}

class _SingleDecimalSeparatorFormatter extends TextInputFormatter {
  const _SingleDecimalSeparatorFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) {
      return newValue;
    }
    if (text.startsWith('.') || text.startsWith(',')) {
      return oldValue;
    }
    final separatorCount = RegExp(r'[,.]').allMatches(text).length;
    if (separatorCount > 1) {
      return oldValue;
    }
    return newValue;
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  const _UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
