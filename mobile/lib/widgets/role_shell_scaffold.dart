import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/connectivity_service.dart';

/// Barra inferior + pestañas compartida por cada panel de rol.
class RoleShellScaffold extends StatefulWidget {
  const RoleShellScaffold({
    super.key,
    required this.api,
    required this.settings,
    required this.destinations,
    required this.tabs,
    this.initialIndex = 0,
    this.patientMode = false,
  });

  final UleamMedApi api;
  final AppSettingsController settings;
  final List<NavigationDestination> destinations;
  final List<Widget> tabs;
  final int initialIndex;
  final bool patientMode;

  @override
  State<RoleShellScaffold> createState() => _RoleShellScaffoldState();
}

class _RoleShellScaffoldState extends State<RoleShellScaffold> {
  final ConnectivityService _connectivity = ConnectivityService();
  StreamSubscription<NetworkStatus>? _networkSubscription;
  NetworkStatus _lastStatus = NetworkStatus.online;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);
    _networkSubscription = _connectivity.watchStatus().listen((status) {
      if (status == NetworkStatus.online &&
          _lastStatus == NetworkStatus.offline) {
        widget.api.synchronizePendingChanges();
      }
      _lastStatus = status;
    });
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.tabs.length) {
      return;
    }
    setState(() => _index = index);
  }

  @override
  void didUpdateWidget(covariant RoleShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.tabs.length) {
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs
        .map(
          (tab) => _RoleTabHost(
            onOpenTab: _goTo,
            activeIndex: _index,
            child: tab,
          ),
        )
        .toList();

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        height: widget.patientMode ? 76 : null,
        labelBehavior: widget.patientMode
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.auto,
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: widget.destinations,
      ),
    );
  }
}

/// Propaga [onOpenTab] a pantallas que lo necesiten dentro del shell.
class _RoleTabHost extends InheritedWidget {
  const _RoleTabHost({
    required this.onOpenTab,
    required this.activeIndex,
    required super.child,
  });

  final ValueChanged<int> onOpenTab;
  final int activeIndex;

  static ValueChanged<int>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RoleTabHost>()
        ?.onOpenTab;
  }

  static int? activeIndexOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_RoleTabHost>()
        ?.activeIndex;
  }

  @override
  bool updateShouldNotify(_RoleTabHost oldWidget) {
    return onOpenTab != oldWidget.onOpenTab ||
        activeIndex != oldWidget.activeIndex;
  }
}

/// Atajo para abrir una pestaña del shell actual desde una pantalla hija.
void openRoleTab(BuildContext context, int index) {
  _RoleTabHost.of(context)?.call(index);
}

/// Indice de la pestaña visible en el shell de rol, si aplica.
int? roleShellActiveTabIndex(BuildContext context) {
  return _RoleTabHost.activeIndexOf(context);
}
