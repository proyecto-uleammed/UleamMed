# UleamMed Mobile

Frontend movil en Flutter para la plataforma UleamMed.

## Estado actual

La app ya esta conectada al backend FastAPI para el flujo demo principal y
cuenta con una primera capa local-first para datos del MVP.

Navegacion principal por barra inferior de 5 destinos: Inicio, Medicamentos,
Historial, Consultas y Perfil. Emergencia queda como acceso rapido desde Inicio.

Pantallas y flujos incluidos:

Las cuentas nuevas empiezan sin datos de ejemplo: cada seccion muestra un
estado vacio que explica que apareceria ahi y como agregar el primer registro.
La sincronizacion es automatica y silenciosa: la app funciona sin conexion y,
cuando la conexion vuelve, envia los cambios pendientes sin mostrar estados de
red al usuario final.

Pantallas y flujos incluidos:

- Onboarding accesible de 3 pasos con opcion de omitir en el primer inicio.
- Inicio con saludo, fecha y hora del dispositivo (con zona horaria local),
  proximas 3 tomas accionables (tomado / posponer 10-15-30-60 min / omitir),
  accesos rapidos y cumplimiento de medicamentos del dia.
- Inicio de sesion y registro con confirmacion de contrasena, requisitos y
  aceptacion de terminos; recuperacion de contrasena por codigo de 6 digitos.
- Perfil medico editable y ajustes de accesibilidad (escala de fuente),
  permisos de recordatorios, bloqueo por PIN y terminos.
- Medicamentos local-first con CRUD, dosis estructurada, intervalos u horas
  especificas, dias, duracion, foto y eventos de toma idempotentes.
- Alarmas Android persistentes con sonido, vibracion, pantalla completa,
  agrupacion de tomas y acciones `Tomado`, `Posponer` y `Omitir`.
- Historial cronologico de tomas con cumplimiento semanal y filtros.
- Condiciones y alergias estructuradas con nivel de severidad (color + texto).
- Consultas CRUD con pestañas de proximas y pasadas, date/time picker, detalle,
  editar, eliminar, marcar realizada y recordatorio configurable.
- Cuidadores: invitacion por correo o telefono y permisos por tipo de dato con
  resumen de informacion compartida.
- Emergencia con datos clave, contactos de emergencia y llamada directa.
- Bloqueo local por PIN con timeout de sesion en segundo plano.
- Pantallas legales de terminos, privacidad y consentimiento.

## Integracion con backend

El cliente HTTP vive en:

```text
lib/services/api_service.dart
```

Endpoints usados actualmente:

- `GET /health`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/forgot-password`
- `POST /api/v1/auth/reset-password`
- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`
- `GET /api/v1/medications`
- `POST /api/v1/medications`
- `PATCH /api/v1/medications/{medication_id}`
- `DELETE /api/v1/medications/{medication_id}`
- `POST /api/v1/medications/{medication_id}/take`
- `POST /api/v1/medications/{medication_id}/dose-events`
- `GET /api/v1/medications/dose-events`
- `POST|GET|DELETE /api/v1/medications/{medication_id}/photo`

La app guarda `access_token` y `refresh_token` con
`flutter_secure_storage`, restaura la sesion al abrir, renueva el access token
cuando recibe `401` y limpia sesion, cache y alarmas al cerrar sesion.

## Modo offline actual

Funcionan sin internet:

- Consultar y editar perfil medico local.
- Consultar, agregar, editar y eliminar medicamentos locales.
- Confirmar toma como `tomado`, `omitido` o `pospuesto` y posponerla.
- Consultar historial local de confirmaciones y cumplimiento semanal.
- Gestionar condiciones, alergias, consultas y contactos de emergencia locales.
- Ver proximas tomas accionables en el inicio.
- Bloqueo por PIN y ajustes de accesibilidad.

Requieren internet o endpoints futuros:

- Crear cuenta nueva.
- Recuperar contrasena.
- Invitar cuidadores.
- Enviar alertas al cuidador en tiempo real.
- Sincronizar datos entre dispositivos.

## URL del backend

Por defecto:

- Produccion: `https://d18ajxqltdcc9k.cloudfront.net`

Tambien se puede configurar manualmente:

```bash
flutter run --dart-define=ULEAMMED_API_URL=https://d18ajxqltdcc9k.cloudfront.net
```

Para desarrollo local (ejemplos):

```bash
# Android Emulator
flutter run --dart-define=ULEAMMED_API_URL=http://10.0.2.2:8000

# Web/Desktop
flutter run --dart-define=ULEAMMED_API_URL=http://127.0.0.1:8000
```

## Ejecutar

```bash
cd mobile
flutter pub get
flutter run
```

## Validar

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Notas para no romper el prototipo

- Si se trabaja contra backend local en Android Emulator, usar `10.0.2.2`.
- No eliminar la inyeccion de `UleamMedApi`; se usa para pruebas.
- No conectar botones a datos falsos si ya existe endpoint en backend.
- Medicamentos conserva los endpoints demo existentes y agrega cache local.
- Citas y emergencias ya leen desde store local, aunque aun usan datos semilla.
- Si se cambia un contrato del backend, actualizar `api_service.dart` y los tests.
- Los pacientes deben habilitar notificaciones, alarmas exactas y pantalla
  completa. Las alarmas funcionan sin internet y se restauran tras reiniciar.
- No solicitar almacenamiento general ni ubicacion. Las fotos usan el selector
  del sistema y los permisos se consultan siempre desde Android.
