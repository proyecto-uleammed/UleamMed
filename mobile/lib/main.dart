import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'services/lock_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const UleamMedApp());
}

class UleamMedApp extends StatefulWidget {
  const UleamMedApp({
    super.key,
    this.api,
    this.settingsController,
    this.lockService,
  });

  final UleamMedApi? api;
  final AppSettingsController? settingsController;
  final LockService? lockService;

  @override
  State<UleamMedApp> createState() => _UleamMedAppState();
}

class _UleamMedAppState extends State<UleamMedApp> with WidgetsBindingObserver {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late final AppSettingsController _settings =
      widget.settingsController ?? AppSettingsController(AppSettingsService());
  late final LockService _lock = widget.lockService ?? LockService();
  DemoSession? _session;
  bool _isRestoringSession = true;
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _settings.load();
    await _restoreSession();
    if (_session != null &&
        _settings.value.appLockEnabled &&
        await _lock.hasPin()) {
      if (mounted) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeLockAfterResume();
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

  void _handleAuthenticated(DemoSession session) {
    setState(() {
      _session = session;
      _locked = false;
    });
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'UleamMed',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(_settings.value.textScaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    if (_isRestoringSession) {
      return const _SessionLoadingScreen();
    }
    if (_session == null) {
      return AuthScreen(api: _api, onAuthenticated: _handleAuthenticated);
    }
    if (_locked) {
      return LockScreen(
        lockService: _lock,
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return MainShell(api: _api, onLogout: _handleLogout, settings: _settings);
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
