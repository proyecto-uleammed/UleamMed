import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_store.dart';

/// Escala de fuente accesible para adultos mayores (PB-010).
enum FontScaleOption {
  normal(1.0, 'Normal'),
  large(1.25, 'Grande'),
  extraLarge(1.5, 'Muy grande');

  const FontScaleOption(this.factor, this.label);

  final double factor;
  final String label;

  static FontScaleOption fromJson(Object? value) {
    return FontScaleOption.values.firstWhere(
      (option) => option.name == value,
      orElse: () => FontScaleOption.normal,
    );
  }
}

/// Rol visible dentro de la app (PB-006). El control real de permisos vive en
/// el backend; aqui solo se adapta la interfaz.
enum AppRole {
  patient('Paciente'),
  caregiver('Cuidador'),
  professional('Medico'),
  admin('Administrador');

  const AppRole(this.label);

  final String label;

  static AppRole fromJson(Object? value) {
    return AppRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => AppRole.patient,
    );
  }
}

@immutable
class AppSettings {
  const AppSettings({
    this.fontScale = FontScaleOption.normal,
    this.role = AppRole.patient,
    this.onboardingSeen = false,
    this.termsAcceptedVersion = '',
    this.appLockEnabled = false,
    this.autoLockMinutes = 2,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fontScale: FontScaleOption.fromJson(json['fontScale']),
      role: AppRole.fromJson(json['role']),
      onboardingSeen: json['onboardingSeen'] == true,
      termsAcceptedVersion: json['termsAcceptedVersion']?.toString() ?? '',
      appLockEnabled: json['appLockEnabled'] == true,
      autoLockMinutes: (json['autoLockMinutes'] as num?)?.toInt() ?? 2,
    );
  }

  final FontScaleOption fontScale;
  final AppRole role;
  final bool onboardingSeen;
  final String termsAcceptedVersion;
  final bool appLockEnabled;
  final int autoLockMinutes;

  double get textScaleFactor => fontScale.factor;

  bool get termsAccepted => termsAcceptedVersion.isNotEmpty;

  AppSettings copyWith({
    FontScaleOption? fontScale,
    AppRole? role,
    bool? onboardingSeen,
    String? termsAcceptedVersion,
    bool? appLockEnabled,
    int? autoLockMinutes,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      role: role ?? this.role,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      termsAcceptedVersion: termsAcceptedVersion ?? this.termsAcceptedVersion,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontScale': fontScale.name,
      'role': role.name,
      'onboardingSeen': onboardingSeen,
      'termsAcceptedVersion': termsAcceptedVersion,
      'appLockEnabled': appLockEnabled,
      'autoLockMinutes': autoLockMinutes,
    };
  }
}

class AppSettingsService {
  AppSettingsService({JsonStore? store}) : _store = store ?? SecureJsonStore();

  final JsonStore _store;

  static const _key = 'uleammed_app_settings';

  Future<AppSettings> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null || raw.trim().isEmpty) {
        return const AppSettings();
      }
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
    } catch (_) {
      return const AppSettings();
    }
    return const AppSettings();
  }

  Future<void> save(AppSettings settings) async {
    try {
      await _store.write(_key, jsonEncode(settings.toJson()));
    } catch (_) {
      // Persistencia local no disponible (por ejemplo en pruebas). Se ignora
      // para no bloquear la interfaz.
    }
  }
}

/// Controlador reactivo para propagar cambios de ajustes a toda la app.
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(
    this._service, {
    AppSettings initial = const AppSettings(),
  }) : _settings = initial;

  final AppSettingsService _service;
  AppSettings _settings;

  AppSettings get value => _settings;

  Future<void> load() async {
    _settings = await _service.load();
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _service.save(settings);
  }

  Future<void> setFontScale(FontScaleOption option) {
    return update(_settings.copyWith(fontScale: option));
  }

  Future<void> setRole(AppRole role) {
    return update(_settings.copyWith(role: role));
  }

  Future<void> markOnboardingSeen() {
    return update(_settings.copyWith(onboardingSeen: true));
  }

  Future<void> acceptTerms(String version) {
    return update(_settings.copyWith(termsAcceptedVersion: version));
  }

  Future<void> setAppLock({required bool enabled, int? autoLockMinutes}) {
    return update(
      _settings.copyWith(
        appLockEnabled: enabled,
        autoLockMinutes: autoLockMinutes,
      ),
    );
  }
}
