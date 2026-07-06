import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const UleamMedApp());
}

class UleamMedApp extends StatefulWidget {
  const UleamMedApp({super.key, this.api});

  final UleamMedApi? api;

  @override
  State<UleamMedApp> createState() => _UleamMedAppState();
}

class _UleamMedAppState extends State<UleamMedApp> {
  late final UleamMedApi _api = widget.api ?? ApiService();
  DemoSession? _session;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
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
    return MaterialApp(
      title: 'UleamMed',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _isRestoringSession
          ? const _SessionLoadingScreen()
          : _session == null
          ? AuthScreen(api: _api, onAuthenticated: _handleAuthenticated)
          : HomeScreen(api: _api, onLogout: _handleLogout),
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
