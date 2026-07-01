# UleamMed

UleamMed es una plataforma movil pensada para asistir a adultos mayores en la gestion diaria de su salud. El sistema contempla recordatorios de medicacion, historial de consultas medicas, monitoreo remoto para cuidadores y una interfaz accesible.

## Backend

El backend esta construido con FastAPI y expone una API REST versionada en `/api/v1`, autenticacion con JWT, notificaciones push demo mediante Firebase Cloud Messaging y un canal WebSocket para eventos en tiempo real.

La base de datos, el modelado de tablas y las migraciones con Alembic se coordinan con el companero responsable de PostgreSQL. En este backend ya quedan preparados los contratos y puntos de integracion.

## Requisitos

- Python 3.12 o superior
- PostgreSQL disponible cuando se conecte la base real
- Entorno virtual de Python
- Credenciales Firebase opcionales para envio real de push

## Configuracion

1. Copiar `.env.example` a `.env`.
2. Ajustar `DATABASE_URL`, `SECRET_KEY` y, si aplica, `FIREBASE_CREDENTIALS`.
3. No subir `.env` ni credenciales Firebase al repositorio.

Variables principales:

- `DATABASE_URL`: conexion de PostgreSQL para SQLAlchemy.
- `SECRET_KEY`: clave usada para firmar tokens JWT.
- `ALGORITHM`: algoritmo JWT, por defecto `HS256`.
- `ACCESS_TOKEN_EXPIRE_MINUTES`: duracion del access token.
- `REFRESH_TOKEN_EXPIRE_DAYS`: duracion del refresh token.
- `FIREBASE_CREDENTIALS`: ruta al JSON de Firebase Admin SDK.
- `CORS_ORIGINS`: origenes permitidos para Flutter Web separados por coma; en desarrollo puede usarse `*`.
- `ENVIRONMENT`: entorno de ejecucion.

## Instalacion

Windows:

```powershell
python -m venv venv
venv\Scripts\pip.exe install -r requirements.txt
```

Linux/macOS:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

## Ejecutar el backend

Windows:

```powershell
venv\Scripts\uvicorn.exe backend.app.main:app --reload
```

Linux/macOS:

```bash
.venv/bin/python -m uvicorn backend.app.main:app --reload
```

Luego abrir:

- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`
- Health check: `http://127.0.0.1:8000/health`

## Endpoints principales

- `POST /api/v1/auth/register`: registrar usuario.
- `POST /api/v1/auth/login`: iniciar sesion.
- `POST /api/v1/auth/refresh`: renovar access token.
- `GET /api/v1/users/me`: ver perfil autenticado.
- `PATCH /api/v1/users/me`: actualizar perfil autenticado.
- `POST /api/v1/devices`: registrar token FCM del dispositivo.
- `GET /api/v1/devices`: listar tokens FCM del usuario.
- `DELETE /api/v1/devices/{token}`: eliminar token FCM.
- `POST /api/v1/notifications/send`: enviar notificacion demo.
- `GET /api/v1/notifications`: listar notificaciones demo.
- `WS /api/v1/ws?token=<access_token>`: canal WebSocket de tiempo real.

## Notas de desarrollo

- Los dispositivos y notificaciones usan almacenamiento demo en memoria hasta que existan tablas reales.
- El WebSocket administra conexiones activas en memoria y no persiste eventos.
- `docu_archive.md` es una bitacora local ignorada por Git.
- Las credenciales Firebase deben quedar fuera del repositorio.
