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

@immutable
class AppSettings {
  const AppSettings({
    this.fontScale = FontScaleOption.normal,
    this.onboardingSeen = false,
    this.termsAcceptedVersion = '',
    this.appLockEnabled = false,
    this.autoLockMinutes = 2,
    this.remindersEnabled = true,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      fontScale: FontScaleOption.fromJson(json['fontScale']),
      onboardingSeen: json['onboardingSeen'] == true,
      termsAcceptedVersion: json['termsAcceptedVersion']?.toString() ?? '',
      appLockEnabled: json['appLockEnabled'] == true,
      autoLockMinutes: (json['autoLockMinutes'] as num?)?.toInt() ?? 2,
      remindersEnabled: json['remindersEnabled'] != false,
    );
  }

  final FontScaleOption fontScale;
  final bool onboardingSeen;
  final String termsAcceptedVersion;
  final bool appLockEnabled;
  final int autoLockMinutes;
  final bool remindersEnabled;

  double get textScaleFactor => fontScale.factor;

  bool get termsAccepted => termsAcceptedVersion.isNotEmpty;

  AppSettings copyWith({
    FontScaleOption? fontScale,
    bool? onboardingSeen,
    String? termsAcceptedVersion,
    bool? appLockEnabled,
    int? autoLockMinutes,
    bool? remindersEnabled,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      onboardingSeen: onboardingSeen ?? this.onboardingSeen,
      termsAcceptedVersion: termsAcceptedVersion ?? this.termsAcceptedVersion,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontScale': fontScale.name,
      'onboardingSeen': onboardingSeen,
      'termsAcceptedVersion': termsAcceptedVersion,
      'appLockEnabled': appLockEnabled,
      'autoLockMinutes': autoLockMinutes,
      'remindersEnabled': remindersEnabled,
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

  Future<void> setRemindersEnabled(bool enabled) {
    return update(_settings.copyWith(remindersEnabled: enabled));
  }
}
