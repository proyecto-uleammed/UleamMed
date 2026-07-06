import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/connectivity_service.dart';
import 'appointments_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'medications_screen.dart';
import 'pending_sync_screen.dart';
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
  final ConnectivityService _connectivity = ConnectivityService();
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
      body: Column(
        children: [
          _OfflineBanner(
            connectivity: _connectivity,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PendingSyncScreen(
                    api: widget.api,
                    connectivity: _connectivity,
                  ),
                ),
              );
            },
          ),
          Expanded(child: IndexedStack(index: _index, children: tabs)),
        ],
      ),
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

/// Banner global no invasivo que avisa cuando no hay conexion (PB-049).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.connectivity, required this.onTap});

  final ConnectivityService connectivity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      initialData: NetworkStatus.online,
      stream: connectivity.watchStatus(),
      builder: (context, snapshot) {
        final offline = snapshot.data == NetworkStatus.offline;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: offline
              ? Material(
                  color: const Color(0xFFF57F17),
                  child: InkWell(
                    onTap: onTap,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Sin conexion. Tus cambios se guardan y se '
                                'sincronizaran despues.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
