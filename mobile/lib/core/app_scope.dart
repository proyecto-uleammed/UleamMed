import 'package:flutter/widgets.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/lock_service.dart';
import '../services/notification_scheduler.dart';
import '../services/permission_service.dart';

/// Contenedor de las dependencias vivas de la aplicacion.
///
/// Se construye una unica vez en `UleamMedApp` y se expone al arbol de widgets
/// mediante [AppScope]. Ninguna pantalla debe instanciar servicios por su
/// cuenta: dos instancias de [ApiService] significan dos caches de token en
/// memoria, dos `http.Client` y un `LocalStore` sin `scopeToUser()` aplicado,
/// lo que puede exponer datos de una cuenta a otra.
class AppDependencies {
  const AppDependencies({
    required this.api,
    required this.settings,
    required this.lock,
    required this.permissions,
    required this.scheduler,
    required this.alarmPluginReady,
  });

  final UleamMedApi api;
  final AppSettingsController settings;
  final LockService lock;
  final PermissionService permissions;
  final NotificationScheduler scheduler;

  /// `false` cuando el plugin de alarmas no pudo inicializarse. La app arranca
  /// igual, en modo degradado, y avisa al usuario.
  final bool alarmPluginReady;

  /// Libera los recursos propios del contenedor.
  ///
  /// No se dispone [settings] a proposito: su ciclo de vida puede ser externo
  /// (las pruebas reutilizan el controlador entre `pumpWidget`) y su unico
  /// coste es memoria que se libera al terminar el proceso.
  void dispose() {
    api.dispose();
  }
}

/// Expone las [AppDependencies] a todo el arbol de widgets.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.dependencies,
    required super.child,
  });

  final AppDependencies dependencies;

  /// Dependencias del scope activo. Lanza en debug si no hay `AppScope`.
  static AppDependencies of(BuildContext context) {
    final dependencies = maybeOf(context);
    assert(
      dependencies != null,
      'No se encontro un AppScope sobre este widget. Envuelve la app con '
      'AppScope o pasa "api:" explicitamente al construir la pantalla.',
    );
    return dependencies!;
  }

  static AppDependencies? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppScope>()
        ?.dependencies;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return !identical(dependencies, oldWidget.dependencies);
  }
}
