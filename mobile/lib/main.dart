import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:alarm/alarm.dart';
import 'core/app_scope.dart';
import 'models/app_role.dart';
import 'screens/auth_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'screens/medication_alarm_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/permissions_screen.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'services/lock_service.dart';
import 'services/medication_schedule_service.dart';
import 'services/notification_scheduler.dart';
import 'services/permission_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final alarmPluginReady = await _initializeAlarmPlugin();
  runApp(UleamMedApp(alarmPluginReady: alarmPluginReady));
}

/// Inicializa el plugin de alarmas sin tumbar el arranque si falla.
///
/// Una excepcion no capturada aqui deja al usuario ante una pantalla negra. En
/// una app de recordatorios medicos preferimos arrancar degradados y avisar.
Future<bool> _initializeAlarmPlugin() async {
  try {
    await Alarm.init();
    return true;
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'uleam_med',
        context: ErrorDescription('inicializando el plugin de alarmas'),
      ),
    );
    return false;
  }
}

class UleamMedApp extends StatefulWidget {
  const UleamMedApp({
    super.key,
    this.api,
    this.settingsController,
    this.lockService,
    this.permissionService,
    this.notificationScheduler,
    this.alarmPluginReady = true,
  });

  final UleamMedApi? api;
  final AppSettingsController? settingsController;
  final LockService? lockService;
  final PermissionService? permissionService;
  final NotificationScheduler? notificationScheduler;
  final bool alarmPluginReady;

  @override
  State<UleamMedApp> createState() => _UleamMedAppState();
}

class _UleamMedAppState extends State<UleamMedApp> with WidgetsBindingObserver {
  late final AppDependencies _dependencies = AppDependencies(
    api: widget.api ?? ApiService(),
    settings:
        widget.settingsController ??
        AppSettingsController(AppSettingsService()),
    lock: widget.lockService ?? LockService(),
    permissions: widget.permissionService ?? AndroidPermissionService(),
    scheduler: widget.notificationScheduler ?? NotificationScheduler(),
    alarmPluginReady: widget.alarmPluginReady,
  );

  // Getters de compatibilidad: el resto del archivo no cambia.
  UleamMedApi get _api => _dependencies.api;
  AppSettingsController get _settings => _dependencies.settings;
  LockService get _lock => _dependencies.lock;
  PermissionService get _permissions => _dependencies.permissions;
  NotificationScheduler get _scheduler => _dependencies.scheduler;

  AppSession? _session;
  bool _isRestoringSession = true;
  bool _permissionsChecked = false;
  bool _permissionsReady = false;
  bool _locked = false;
  int _patientInitialTab = 0;
  int _shellGeneration = 0;
  DateTime? _pausedAt;
  final _navigatorKey = GlobalKey<NavigatorState>();
  (int, List<MedicationOccurrence>)? _pendingAlarm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dependencies.dispose();
    super.dispose();
  }

  /// Arranque por etapas. Ninguna etapa puede impedir que la app se muestre.
  Future<void> _bootstrap() async {
    await _settings.load();
    await _initializeScheduler();
    await _restoreSession();
    await _preparePatientPermissions();
    await _applyLockIfNeeded();
    if (!_dependencies.alarmPluginReady) {
      _warnAlarmsUnavailable();
    }
  }

  Future<void> _initializeScheduler() async {
    if (!_dependencies.alarmPluginReady) {
      return;
    }
    try {
      final openedFromReminder = await _scheduler.initialize(
        onOpenMedications: _openMedications,
        onAlarmRinging: _showMedicationAlarm,
      );
      if (openedFromReminder) {
        _patientInitialTab = 0;
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'inicializando el programador de alarmas');
    }
  }

  /// Vuelve a programar las alarmas. Si no hay red, se reintenta al reanudar.
  Future<void> _reconcileReminders() async {
    try {
      final medications = await _api.listMedications();
      await _scheduler.reconcile(medications);
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'reprogramando alarmas de medicamentos');
    }
  }

  /// Comprueba los permisos del paciente.
  ///
  /// `_permissionsChecked` DEBE quedar en `true` en toda ruta de salida: si no,
  /// la app se queda colgada en la pantalla "Validando sesion..." para siempre.
  Future<void> _preparePatientPermissions() async {
    if (_session?.user.role != AppRole.patient) {
      return;
    }

    var isReady = false;
    try {
      final snapshot = await _permissions.check();
      isReady = snapshot.isReady;
      if (isReady) {
        await _reconcileReminders();
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'preparando permisos del paciente');
    } finally {
      if (mounted) {
        setState(() {
          _permissionsChecked = true;
          _permissionsReady = isReady;
        });
      }
    }
  }

  Future<void> _applyLockIfNeeded() async {
    if (_session == null || !_settings.value.appLockEnabled) {
      return;
    }
    try {
      if (await _lock.hasPin() && mounted) {
        setState(() => _locked = true);
      }
    } catch (error, stackTrace) {
      _reportError(error, stackTrace, 'verificando el bloqueo con PIN');
    }
  }

  void _reportError(Object error, StackTrace stackTrace, String stage) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'uleam_med',
        context: ErrorDescription(stage),
      ),
    );
  }

  /// Avisa que las alarmas no funcionaran. El paciente debe saberlo.
  void _warnAlarmsUnavailable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = _navigatorKey.currentContext;
      if (!mounted || navigatorContext == null) {
        return;
      }
      final messenger = ScaffoldMessenger.of(navigatorContext);
      messenger.showMaterialBanner(
        MaterialBanner(
          leading: const Icon(Icons.alarm_off, color: Color(0xFFC62828)),
          content: const Text(
            'Las alarmas de medicamentos no estan disponibles en este '
            'telefono. Revisa tus medicinas manualmente.',
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeLockAfterResume();
      _refreshPermissionsAfterResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    }
  }

  Future<void> _maybeLockAfterResume() async {
    if (_session == null || !_settings.value.appLockEnabled || _locked) {
      return;
    }
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(pausedAt);
    if (elapsed.inMinutes < _settings.value.autoLockMinutes) {
      return;
    }
    if (await _lock.hasPin() && mounted) {
      setState(() => _locked = true);
    }
  }

  Future<void> _refreshPermissionsAfterResume() async {
    if (_session?.user.role != AppRole.patient) {
      return;
    }
    final snapshot = await _permissions.check();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionsChecked = true;
      _permissionsReady = snapshot.isReady;
    });
    if (snapshot.isReady) {
      await _reconcileReminders();
    }
  }

  Future<void> _restoreSession() async {
    try {
      final session = await _api.restoreSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _isRestoringSession = false;
      });
      await _applyPatientAccessibilityDefaults();
      _openPendingAlarm();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _session = null;
        _isRestoringSession = false;
      });
    }
  }

  void _handleAuthenticated(AppSession session) {
    setState(() {
      _session = session;
      _locked = false;
      _permissionsChecked = session.user.role != AppRole.patient;
      _permissionsReady = session.user.role != AppRole.patient;
    });
    unawaited(_applyPatientAccessibilityDefaults());
    _preparePatientPermissions();
    _openPendingAlarm();
  }

  Future<void> _applyPatientAccessibilityDefaults() async {
    if (_session?.user.role != AppRole.patient) {
      return;
    }
    if (_settings.value.fontScale == FontScaleOption.normal) {
      await _settings.setFontScale(FontScaleOption.large);
    }
  }

  double _textScaleFactor() {
    final base = _settings.value.textScaleFactor;
    if (_session?.user.role == AppRole.patient) {
      return base.clamp(
        FontScaleOption.large.factor,
        FontScaleOption.extraLarge.factor,
      );
    }
    return base;
  }

  Future<void> _handleLogout() async {
    await _scheduler.cancelAll();
    await _api.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _locked = false;
      _permissionsChecked = false;
      _permissionsReady = false;
      _patientInitialTab = 0;
    });
  }

  void _completePermissionSetup() {
    setState(() {
      _permissionsChecked = true;
      _permissionsReady = true;
    });
  }

  void _openMedications() {
    if (!mounted) {
      _patientInitialTab = 0;
      return;
    }
    setState(() {
      _patientInitialTab = 0;
      _shellGeneration++;
    });
  }

  void _showMedicationAlarm(
    int alarmId,
    List<MedicationOccurrence> occurrences,
  ) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || _session == null) {
      _pendingAlarm = (alarmId, occurrences);
      return;
    }
    unawaited(
      navigator
          .push<bool>(
            MaterialPageRoute<bool>(
              fullscreenDialog: true,
              builder: (_) => MedicationAlarmScreen(
                alarmId: alarmId,
                occurrences: occurrences,
                api: _api,
                scheduler: _scheduler,
              ),
            ),
          )
          .then((updated) {
            if (updated == true && mounted) {
              _openMedications();
            }
          }),
    );
  }

  void _openPendingAlarm() {
    final pending = _pendingAlarm;
    if (pending == null || _session == null) {
      return;
    }
    _pendingAlarm = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMedicationAlarm(pending.$1, pending.$2);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: _dependencies,
      child: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'UleamMed',
            debugShowCheckedModeBanner: false,
            locale: const Locale('es', 'ES'),
            supportedLocales: const [
              Locale('es', 'ES'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildAppTheme(),
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(_textScaleFactor()),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: _buildHome(),
          );
        },
      ),
    );
  }

  Widget _buildHome() {
    if (_isRestoringSession) {
      return const _SessionLoadingScreen();
    }
    if (_session == null) {
      if (!_settings.value.onboardingSeen) {
        return OnboardingScreen(onDone: () => _settings.markOnboardingSeen());
      }
      return AuthScreen(api: _api, onAuthenticated: _handleAuthenticated);
    }
    if (_locked) {
      return LockScreen(
        lockService: _lock,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    if (_session!.user.role == AppRole.patient && !_permissionsChecked) {
      return const _SessionLoadingScreen();
    }
    if (_session!.user.role == AppRole.patient && !_permissionsReady) {
      return PermissionsScreen(
        permissions: _permissions,
        scheduler: _scheduler,
        api: _api,
        onComplete: _completePermissionSetup,
        onLogout: _handleLogout,
      );
    }
    return MainShell(
      key: ValueKey(_shellGeneration),
      api: _api,
      onLogout: _handleLogout,
      settings: _settings,
      role: _session!.user.role,
      permissionService: _permissions,
      notificationScheduler: _scheduler,
      patientInitialTab: _patientInitialTab,
    );
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.health_and_safety, size: 56, color: AppColors.primary),
            SizedBox(height: 18),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Validando sesion...'),
          ],
        ),
      ),
    );
  }
}
