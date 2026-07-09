import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

enum AppPermissionState { granted, denied, permanentlyDenied, unsupported }

@immutable
class ReminderPermissionSnapshot {
  const ReminderPermissionSnapshot({
    required this.notifications,
    required this.exactAlarms,
    required this.fullScreen,
  });

  final AppPermissionState notifications;
  final AppPermissionState exactAlarms;
  final AppPermissionState fullScreen;

  bool get isReady =>
      notifications == AppPermissionState.granted &&
      exactAlarms == AppPermissionState.granted &&
      fullScreen == AppPermissionState.granted;
}

abstract class PermissionService {
  Future<ReminderPermissionSnapshot> check();
  Future<AppPermissionState> requestNotifications();
  Future<AppPermissionState> requestExactAlarms();
  Future<AppPermissionState> requestFullScreen();
  Future<bool> openSettings();
}

class AndroidPermissionService implements PermissionService {
  static const _channel = MethodChannel('uleammed/permissions');

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<ReminderPermissionSnapshot> check() async {
    if (!_isAndroid) {
      return const ReminderPermissionSnapshot(
        notifications: AppPermissionState.unsupported,
        exactAlarms: AppPermissionState.unsupported,
        fullScreen: AppPermissionState.unsupported,
      );
    }
    final fullScreen = await _channel.invokeMethod<bool>(
      'canUseFullScreenIntent',
    );
    return ReminderPermissionSnapshot(
      notifications: _map(await handler.Permission.notification.status),
      exactAlarms: _map(await handler.Permission.scheduleExactAlarm.status),
      fullScreen: fullScreen == true
          ? AppPermissionState.granted
          : AppPermissionState.denied,
    );
  }

  @override
  Future<AppPermissionState> requestNotifications() async {
    if (!_isAndroid) {
      return AppPermissionState.unsupported;
    }
    return _map(await handler.Permission.notification.request());
  }

  @override
  Future<AppPermissionState> requestExactAlarms() async {
    if (!_isAndroid) {
      return AppPermissionState.unsupported;
    }
    return _map(await handler.Permission.scheduleExactAlarm.request());
  }

  @override
  Future<AppPermissionState> requestFullScreen() async {
    if (!_isAndroid) {
      return AppPermissionState.unsupported;
    }
    await _channel.invokeMethod<void>('requestFullScreenIntent');
    final allowed = await _channel.invokeMethod<bool>('canUseFullScreenIntent');
    return allowed == true
        ? AppPermissionState.granted
        : AppPermissionState.denied;
  }

  @override
  Future<bool> openSettings() => handler.openAppSettings();

  AppPermissionState _map(handler.PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return AppPermissionState.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return AppPermissionState.permanentlyDenied;
    }
    return AppPermissionState.denied;
  }
}
