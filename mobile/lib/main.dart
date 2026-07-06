import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const UleamMedApp());
}

class UleamMedApp extends StatefulWidget {
  const UleamMedApp({super.key, this.api, this.settingsController});

  final UleamMedApi? api;
  final AppSettingsController? settingsController;

  @override
  State<UleamMedApp> createState() => _UleamMedAppState();
}

class _UleamMedAppState extends State<UleamMedApp> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  late final AppSettingsController _settings =
      widget.settingsController ??
      AppSettingsController(service: AppSettingsService());
  DemoSession? _session;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _settings.load();
    await _restoreSession();
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
    });
  }

  Future<void> _handleLogout() async {
    await _api.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
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
          home: _isRestoringSession
              ? const _SessionLoadingScreen()
              : _session == null
              ? AuthScreen(api: _api, onAuthenticated: _handleAuthenticated)
              : MainShell(
                  api: _api,
                  onLogout: _handleLogout,
                  settings: _settings,
                ),
        );
      },
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
