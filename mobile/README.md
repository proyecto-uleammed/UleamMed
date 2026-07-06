# UleamMed Mobile

Frontend movil en Flutter para la plataforma UleamMed.

## Estado actual

La app ya esta conectada al backend FastAPI para el flujo demo principal.

Pantallas incluidas:

- Inicio con saludo, estado de animo, estado de conexion backend y resumen del dia.
- Pantalla inicial para iniciar sesion o crear cuenta.
- Recuperacion de contrasena preparada; valida correo, pero aun no envia email real.
- Perfil basico editable con nombre y correo del usuario autenticado.
- Medicamentos conectado al backend.
- Citas medicas demo.
- Actividades del dia demo.
- Contactos de emergencia demo.

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
- `POST /api/v1/medications/{medication_id}/take`

La app guarda `access_token` y `refresh_token` con `flutter_secure_storage`, restaura la sesion al abrir, renueva el access token cuando recibe `401` y limpia la sesion al cerrar sesion. La recuperacion de contrasena solicita un codigo de 6 digitos y permite guardar una nueva contrasena. Tambien conserva un modo demo manual para desarrollo:

```text
roberto@uleammed.demo
```

## URL del backend

Por defecto:

- Android Emulator: `http://10.0.2.2:8000`
- Web/Desktop: `http://127.0.0.1:8000`

Tambien se puede configurar manualmente:

```bash
flutter run --dart-define=ULEAMMED_API_URL=http://10.0.2.2:8000
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

- No cambiar `10.0.2.2` por `127.0.0.1` para Android Emulator.
- No eliminar la inyeccion de `UleamMedApi`; se usa para pruebas.
- No conectar botones a datos falsos si ya existe endpoint en backend.
- Medicamentos ya esta conectado; citas, actividades y emergencias siguen demo.
- Si se cambia un contrato del backend, actualizar `api_service.dart` y los tests.
