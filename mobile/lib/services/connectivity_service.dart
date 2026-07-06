import 'dart:async';

enum NetworkStatus { online, offline }

class ConnectivityService {
  const ConnectivityService();

  Future<NetworkStatus> currentStatus() async {
    return NetworkStatus.online;
  }

  Stream<NetworkStatus> watchStatus() {
    return Stream<NetworkStatus>.value(NetworkStatus.online);
  }
}
