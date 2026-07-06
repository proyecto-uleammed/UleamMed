import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import 'appointments_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'profile_screen.dart';

/// Contenedor principal con navegacion inferior de 5 modulos (PB-008).
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.api,
    required this.onLogout,
    required this.settings,
  });

  final UleamMedApi api;
  final Future<void> Function() onLogout;
  final AppSettingsController settings;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _goTo(int index) {
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(
        api: widget.api,
        onLogout: widget.onLogout,
        settings: widget.settings,
        onOpenTab: _goTo,
      ),
      MedicationsScreen(api: widget.api),
      HistoryScreen(api: widget.api),
      AppointmentsScreen(api: widget.api),
      ProfileScreen(api: widget.api, settings: widget.settings),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medicinas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history_toggle_off),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Consultas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
