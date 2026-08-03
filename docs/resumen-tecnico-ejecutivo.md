# Resumen técnico ejecutivo — UleamMed

**Fecha:** 3 de agosto de 2026  
**Rama de referencia:** `Frontend-backend` (PR [#21](https://github.com/proyecto-uleammed/UleamMed/pull/21) abierto)  
**Tipo de producto:** Prototipo funcional móvil para asistencia sanitaria de adultos mayores

---

## 1. Visión general

UleamMed es una plataforma móvil que ayuda a adultos mayores a gestionar medicamentos, consultas y datos de salud, con apoyo de cuidadores. El prototipo actual combina:

- **App Flutter** (`mobile/`) con paneles por rol y capa local-first.
- **API FastAPI** (`backend/`) versionada en `/api/v1`.
- **PostgreSQL / Supabase** como base de datos y almacenamiento de fotos.
- **CI/CD** con GitHub Actions, validación de backend/Flutter y publicación hacia AWS ECR/ECS.

La arquitectura sigue un modelo **cliente → API → base de datos**: Flutter no accede directamente a Supabase; todo pasa por FastAPI con JWT propio.

---

## 2. Arquitectura actual

```text
┌─────────────────────┐
│  Flutter (mobile/)  │  Paneles: paciente / cuidador / admin / médico*
│  LocalStore offline │  Alarmas Android, sync silenciosa
└──────────┬──────────┘
           │ HTTPS / JWT
┌──────────▼──────────┐
│  FastAPI /api/v1    │  Auth, medicamentos, caregiving, citas,
│  SQLAlchemy + Alembic│  perfil médico, condiciones, contactos
└──────────┬──────────┘
           │
┌──────────▼──────────┐
│ PostgreSQL/Supabase │  Datos persistentes + Storage (fotos)
└─────────────────────┘

CI: GitHub Actions → pytest / flutter analyze+test+APK → ECR/ECS
```

\*Panel médico: estructura UI presente; funcionalidad aún limitada/placeholder.

### Capas principales

| Capa | Ubicación | Responsabilidad |
|------|-----------|-----------------|
| UI / roles | `mobile/lib/screens/`, `roles/` | Pantallas por rol y navegación |
| Cliente HTTP | `mobile/lib/services/api_service.dart` | Auth, refresh, CRUD remoto |
| Offline | `mobile/lib/services/local_store.dart` | Cache, cola de sync, PIN |
| API | `backend/api/v1/endpoints/` | Contratos REST |
| Dominio | `backend/services/` | Reglas de negocio |
| Persistencia | `backend/models/` + Alembic | MER y migraciones |
| Infra | `.github/workflows/`, `infra/aws/` | Validación y despliegue |

---

## 3. Tecnologías

### Backend

- Python 3.12, FastAPI, Uvicorn
- SQLAlchemy, Alembic, PostgreSQL (`psycopg`)
- Pydantic / pydantic-settings
- JWT (`python-jose`), Passlib/bcrypt
- Supabase Storage (fotos de medicamentos)
- Firebase Admin (push, parcialmente demo)
- WebSockets (canal demo en memoria)

### Frontend

- Flutter / Dart SDK ^3.12
- `http`, `flutter_secure_storage`
- `connectivity_plus`, `image_picker`, `path_provider`
- `alarm`, `flutter_local_notifications`, `permission_handler`
- `url_launcher`, localizaciones en español

### Infraestructura y calidad

- GitHub Actions (`ci-validacion-pr`, `ci-flutter`, `ci-aws-ecr-main`, `cd-ecs-main`)
- Docker (imagen backend)
- AWS ECR / ECS / CloudFront (producción parcial)
- Ruff, pytest, `flutter analyze` / `flutter test` / build APK debug

---

## 4. Módulos completados (o en estado MVP usable)

### Autenticación y usuarios

- Registro, login, refresh token, recuperación de contraseña
- Rol persistido en PostgreSQL (`patient` / `caregiver`)
- Sesión segura en Flutter con restauración automática

### Medicamentos

- CRUD completo paciente y cuidador (con vínculo activo)
- Horarios por intervalo u horas específicas, dosis, duración
- Eventos de toma (tomado / posponer / omitir)
- Fotos autenticadas (Supabase Storage)
- Papelera y restauración
- Alarmas Android offline (pantalla completa, sonido/vibración)
- Sync offline de medicamentos

### Vinculación paciente–cuidador

- Código temporal de un solo uso
- Aprobación / rechazo / revocación
- Hub del cuidador: medicamentos, consultas, condiciones, contactos

### Salud y consultas

- Perfil médico compartido
- Condiciones y alergias (CRUD bidireccional)
- Consultas médicas (API + UI, sync cuidador↔paciente)
- Contactos de emergencia con llamada directa
- Historial de tomas y cumplimiento semanal

### Experiencia paciente (accesibilidad)

- Panel simplificado a **3 módulos**: Medicinas, Consultas, Mi salud
- Modo **solo lectura** para el paciente (edición en cuidador)
- Texto grande por defecto y navegación ampliada
- Pull-to-refresh como mecanismo principal de recarga

### Panel administrador

- Shell y pantallas base (usuarios, reportes, sistema, perfil)

### Base de datos e integración

- MER con migraciones Alembic
- Backend desplegable con secrets/variables de entorno
- Tests de flujo backend (~17 casos) y widget tests Flutter actualizados

---

## 5. Estado por rol

| Rol | Estado |
|-----|--------|
| **Paciente** | MVP accesible usable; consulta y confirmación de tomas |
| **Cuidador** | MVP funcional; gestiona datos del paciente vinculado |
| **Administrador** | UI base; sin operaciones administrativas profundas |
| **Médico / profesional** | Shell/placeholder; no es flujo productivo |

---

## 6. Pendientes prioritarios

### Producto / funcionalidad

1. **Merge del PR #21** a `main` (panel paciente accesible).
2. **Completar panel administrador** (gestión real de usuarios/reportes).
3. **Activar o retirar el rol médico** con alcance claro.
4. **Push notifications reales** (hoy hay endpoints/demo en memoria).
5. **WebSocket productivo** (hoy conexiones en memoria).
6. **Alertas en tiempo real al cuidador** ante tomas omitidas / emergencias.
7. **Sincronización multi-dispositivo** más robusta fuera de medicamentos.
8. **Dispositivos FCM persistidos** en tablas reales (no solo demo).

### Infraestructura / calidad

9. **Corregir OIDC AWS** (`sts:AssumeRoleWithWebIdentity`) que falla al publicar en ECR.
10. Estabilizar **CD ECS** de punta a punta en `main`.
11. Actualizar el **README raíz**, que aún describe pantallas demo desactualizadas frente a `Frontend-backend`.
12. Ampliar cobertura de pruebas (integración cuidador, sync offline, fotos).

### UX / accesibilidad

13. Validación formal de usabilidad con adultos mayores.
14. Publicación de APK/release (hoy se valida build debug en CI).

---

## 7. Riesgos conocidos

- El repositorio sigue siendo un **prototipo**: conviven módulos reales y demos.
- `main` local puede estar **desactualizado** respecto a `Frontend-backend`.
- El fallo de **ECR/OIDC** no bloquea desarrollo, pero sí el pipeline de publicación de imagen.
- Cambios de contrato API requieren actualizar `api_service.dart` y tests en conjunto.

---

## 8. Conclusión

UleamMed ya cuenta con un **MVP integrado** usable para el flujo principal paciente–cuidador: autenticación, medicamentos con alarmas, consultas, perfil/condiciones, vinculación y operación offline parcial. Lo pendiente se concentra en **roles secundarios (admin/médico)**, **notificaciones/tiempo real productivos**, **estabilización del despliegue AWS** y **cierre del PR de accesibilidad del paciente en `main`**.
