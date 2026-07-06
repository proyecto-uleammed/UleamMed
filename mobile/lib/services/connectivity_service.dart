import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

/// Envuelve connectivity_plus con una API sencilla y tolerante a fallos.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  NetworkStatus _map(List<ConnectivityResult> results) {
    final offline =
        results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);
    return offline ? NetworkStatus.offline : NetworkStatus.online;
  }

  Future<NetworkStatus> currentStatus() async {
    try {
      return _map(await _connectivity.checkConnectivity());
    } catch (_) {
      return NetworkStatus.online;
    }
  }

  Stream<NetworkStatus> watchStatus() {
    return _connectivity.onConnectivityChanged.map(_map);
  }
}
