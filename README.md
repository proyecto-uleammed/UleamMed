# UleamMed

UleamMed es una plataforma movil pensada para asistir a adultos mayores en la gestion diaria de su salud. El prototipo actual integra una app Flutter con un backend FastAPI para probar el flujo base de autenticacion, perfil y medicamentos.

## Estado actual del prototipo

Ya esta integrado en `main`:

- Backend FastAPI con API REST versionada en `/api/v1`.
- Autenticacion con JWT: registro, login, refresh y perfil.
- Frontend Flutter dentro de `mobile/`.
- Conexion Flutter -> FastAPI mediante `mobile/lib/services/api_service.dart`.
- Demo de usuario automatico: `roberto@uleammed.demo`.
- Modulo de medicamentos conectado al backend:
  - `GET /api/v1/medications`
  - `POST /api/v1/medications/{medication_id}/take`
  - El boton `Marcar` cambia el medicamento a `Tomado`.
  - El Home actualiza el resumen, por ejemplo `3 de 4 tomados hoy`.
- Notificaciones y dispositivos demo en memoria.
- WebSocket autenticado demo.
- CI inicial con GitHub Actions.
- Preparacion para publicar imagen Docker del backend en AWS ECR.

## Importante antes de modificar

Este repositorio todavia es un prototipo. Hay partes reales y partes demo.

No romper estas reglas:

- No subir `.env`, credenciales Firebase, llaves AWS ni secretos.
- No asumir que PostgreSQL ya esta modelado. La base real y Alembic siguen pendientes.
- No reemplazar el flujo de autenticacion sin revisar `backend/core/security.py`, `backend/api/deps.py` y `mobile/lib/services/api_service.dart`.
- No borrar los endpoints demo de medicamentos hasta que existan tablas reales equivalentes.
- No editar carpetas generadas de Flutter (`android`, `ios`, `macos`, `windows`, `linux`, `web`) salvo que el cambio sea especifico de plataforma.
- No cambiar `10.0.2.2` por `127.0.0.1` para Android: el emulador usa `10.0.2.2` para llegar al backend de la computadora.
- No tratar CI-AWS como despliegue completo. Hoy solo valida y prepara/publica imagen en ECR cuando se configuren los secretos.

Si otra IA trabaja en el proyecto, primero debe leer este README, revisar `git status`, correr pruebas y respetar lo que ya esta conectado.

## Estructura principal

```text
backend/                 API FastAPI
backend/api/v1/endpoints Endpoints REST y WebSocket
backend/schemas          Contratos Pydantic
backend/services         Logica de negocio demo y servicios
mobile/                  App Flutter
mobile/lib/screens       Pantallas de la app
mobile/lib/services      Cliente HTTP hacia el backend
tests/                   Pruebas integradas del backend
.github/workflows        CI de validacion y AWS/ECR
docs/                    Documentacion de CI/AWS
infra/aws                Plantillas de politicas AWS
```

## Backend

El backend esta construido con FastAPI y expone:

- API REST versionada en `/api/v1`.
- Swagger UI en `/docs`.
- ReDoc en `/redoc`.
- Health check en `/health`.
- JWT para autenticacion.
- WebSocket demo en `/api/v1/ws?token=<access_token>`.

### Endpoints principales

- `POST /api/v1/auth/register`: registrar usuario.
- `POST /api/v1/auth/login`: iniciar sesion.
- `POST /api/v1/auth/refresh`: renovar access token.
- `GET /api/v1/users/me`: ver perfil autenticado.
- `PATCH /api/v1/users/me`: actualizar perfil autenticado.
- `GET /api/v1/medications`: listar medicamentos demo del usuario.
- `POST /api/v1/medications/{medication_id}/take`: marcar medicamento como tomado.
- `POST /api/v1/devices`: registrar token FCM del dispositivo.
- `GET /api/v1/devices`: listar tokens FCM del usuario.
- `DELETE /api/v1/devices/{token}`: eliminar token FCM.
- `POST /api/v1/notifications/send`: enviar notificacion demo.
- `GET /api/v1/notifications`: listar notificaciones demo.
- `WS /api/v1/ws?token=<access_token>`: canal WebSocket de tiempo real.

### Datos demo temporales

Estos modulos usan memoria temporal:

- Medicamentos: `backend/services/medication_service.py`.
- Dispositivos y notificaciones: `backend/services/notification_service.py`.
- WebSocket: conexiones activas en memoria.

Cuando el modulo de base de datos este listo, se deben reemplazar por tablas y consultas reales sin cambiar el contrato que consume Flutter, salvo que se coordine con frontend.

## Base de datos

La configuracion esta preparada para SQLAlchemy y PostgreSQL mediante `DATABASE_URL`.

Pendiente:

- Modelado final de tablas.
- Migraciones reales con Alembic.
- Persistencia real de medicamentos, tomas, notificaciones, citas y actividades.

Para demo local se puede usar SQLite temporal, solo para probar el prototipo:

```bash
rm -f /tmp/uleammed-demo.db
DATABASE_URL='sqlite:////tmp/uleammed-demo.db' SECRET_KEY='demo-secret-key' .venv/bin/python - <<'PY'
from backend.core.database import Base, engine
from backend.models.user import User

Base.metadata.create_all(bind=engine)
print('demo database ready')
PY
```

## Requisitos

Backend:

- Python 3.12 o superior.
- Entorno virtual de Python.
- PostgreSQL cuando se conecte la base real.
- Credenciales Firebase opcionales para envio real de push.

Frontend:

- Flutter SDK.
- Android SDK si se prueba en emulador.
- JDK 17 recomendado para Android.

## Configuracion backend

Copiar `.env.example` a `.env` si existe, o crear `.env` local.

Variables principales:

- `DATABASE_URL`: conexion de PostgreSQL o SQLite demo.
- `SECRET_KEY`: clave usada para firmar tokens JWT.
- `ALGORITHM`: algoritmo JWT, por defecto `HS256`.
- `ACCESS_TOKEN_EXPIRE_MINUTES`: duracion del access token.
- `REFRESH_TOKEN_EXPIRE_DAYS`: duracion del refresh token.
- `FIREBASE_CREDENTIALS`: ruta al JSON de Firebase Admin SDK.
- `CORS_ORIGINS`: origenes permitidos para Flutter Web; en desarrollo puede usarse `*`.
- `ENVIRONMENT`: entorno de ejecucion.

## Instalacion backend

Linux/macOS:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m pip install ruff pip-audit
```

Windows:

```powershell
python -m venv venv
venv\Scripts\pip.exe install -r requirements.txt
venv\Scripts\pip.exe install ruff pip-audit
```

## Ejecutar backend

Con PostgreSQL o `.env` configurado:

```bash
.venv/bin/python -m uvicorn backend.app.main:app --reload
```

Para Android Emulator es mejor escuchar en todas las interfaces:

```bash
DATABASE_URL='sqlite:////tmp/uleammed-demo.db' SECRET_KEY='demo-secret-key' \
.venv/bin/python -m uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Abrir:

- `http://127.0.0.1:8000/docs`
- `http://127.0.0.1:8000/health`

## Frontend Flutter

La app esta en `mobile/`.

Pantallas actuales:

- Home con estado de animo, conexion backend y resumen.
- Medicamentos conectado al backend.
- Citas medicas demo.
- Actividades demo.
- Emergencias demo.

El cliente HTTP esta en:

- `mobile/lib/services/api_service.dart`

URL del backend:

- Android Emulator: `http://10.0.2.2:8000`
- Web/Desktop: `http://127.0.0.1:8000`
- Se puede sobreescribir con `--dart-define=ULEAMMED_API_URL=<url>`.

Ejecutar:

```bash
cd mobile
flutter pub get
flutter run
```

Ejemplo con URL manual:

```bash
flutter run -d emulator-5554 --dart-define=ULEAMMED_API_URL=http://10.0.2.2:8000
```

## Flujo de demo probado

1. Levantar backend en puerto `8000`.
2. Abrir app Flutter en Android Emulator.
3. Home muestra `Backend conectado`.
4. Entrar a Medicamentos.
5. Presionar `Marcar` en Omeprazol.
6. El medicamento cambia a `Tomado`.
7. El contador pasa de `2 de 4` a `3 de 4`.
8. Al volver al Home, el card de Medicamentos tambien muestra `3 de 4 tomados hoy`.

## Validaciones antes de subir cambios

Backend:

```bash
.venv/bin/python -m ruff check backend tests
.venv/bin/python -m unittest discover -s tests -v
```

Frontend:

```bash
cd mobile
flutter analyze
flutter test
```

Build Android opcional:

```bash
cd mobile
flutter build apk --debug
```

## CI y AWS

Workflows incluidos:

- `.github/workflows/ci-validacion-pr.yml`
  - Corre en Pull Requests hacia `main` o `develop`.
  - Valida backend usando el workflow reutilizable.
- `.github/workflows/reutilizable-validacion-backend.yml`
  - Instala dependencias, corre `ruff`, pruebas y `pip-audit` informativo.
- `.github/workflows/ci-aws-ecr-main.yml`
  - Corre en push a `main`.
  - Valida backend.
  - Construye imagen Docker.
  - Publica imagen en AWS ECR si AWS esta configurado.

Pendiente para activar AWS:

- Configurar `AWS_REGION` en GitHub Actions Variables.
- Configurar `AWS_ECR_REPOSITORY` en GitHub Actions Variables.
- Configurar `AWS_ROLE_ARN` en GitHub Actions Secrets.
- Crear proveedor OIDC y rol IAM en AWS.

Documentacion:

- `docs/ci_aws_largo_plazo.md`
- `docs/activacion_final_ci.md`
- `infra/aws/politica-confianza-oidc-github.json`
- `infra/aws/politica-permisos-ci-ecr.json`

## Pendientes conocidos

- Base de datos real y migraciones Alembic.
- Reemplazar almacenamiento en memoria por persistencia real.
- Login visual real en Flutter; hoy la app usa usuario demo automatico.
- Refactorizar datos estaticos de citas, actividades y emergencias.
- Conectar citas, actividades y emergencias al backend cuando existan endpoints.
- Mejorar validaciones de UX y accesibilidad.
- Agregar CI para Flutter.
- Definir despliegue real del backend despues de ECR.

## Guia rapida para futuros cambios

- Si se cambia un endpoint, actualizar `mobile/lib/services/api_service.dart`.
- Si se cambia un schema del backend, actualizar tests y frontend al mismo tiempo.
- Si se crea persistencia real, mantener compatibilidad con los endpoints actuales mientras se migra.
- Si se toca Flutter, correr `flutter analyze` y `flutter test`.
- Si se toca backend, correr `ruff` y `unittest`.
- Si se usa IA, pedirle que respete este README y que no invente dependencias ni borre flujos ya probados.
