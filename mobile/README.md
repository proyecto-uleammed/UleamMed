# UleamMed Mobile

Frontend movil en Flutter para la plataforma UleamMed.

## Estado actual

La app ya esta conectada al backend FastAPI para el flujo demo principal.

Pantallas incluidas:

- Inicio con saludo, estado de animo, estado de conexion backend y resumen del dia.
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
- `GET /api/v1/users/me`
- `GET /api/v1/medications`
- `POST /api/v1/medications/{medication_id}/take`

La app crea/inicia sesion con un usuario demo para poder presentar el prototipo sin pantalla de login todavia:

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
