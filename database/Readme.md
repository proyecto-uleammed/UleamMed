# Base de Datos - UleamMed

Este modulo documenta el estado actual de PostgreSQL/Supabase y las reglas para
seguir trabajando con Alembic sin romper el backend.

## Stack

- PostgreSQL/Supabase
- SQLAlchemy
- Alembic
- psycopg

## Regla oficial de nombres

- Base de datos, modelos SQLAlchemy y columnas: ingles tecnico en `snake_case`.
- API JSON: ingles; se mantiene `camelCase` solo donde Flutter ya lo consume.
- Texto visible para usuarios: espanol.
- No crear tablas nuevas en espanol.

## Tablas activas

Las tablas activas del backend actual son:

- `users`
- `password_reset_tokens`
- `medications`
- `guardians`
- `caregivers`
- `older_adults`
- `caregiver_older_adults`
- `medical_profiles`
- `medical_histories`
- `medical_exams`
- `exam_details`
- `exam_parameters`
- `medication_catalog`
- `treatments`
- `treatment_medications`
- `medication_adherence_records`
- `notifications`
- `notification_recipients`
- `fcm_tokens`

## Contrato actual del MVP

- Auth usa `users`.
- Recuperacion de contrasena usa `password_reset_tokens`.
- Medicamentos personales usan `medications`.
- Cada medicamento pertenece a `users.id` por `medications.user_id`.
- Flutter nunca debe enviar `user_id`; el backend lo toma del token JWT.

## Migraciones Alembic

Las migraciones viven dentro de `backend/alembic/`.

La revision actual validada es:

```bash
alembic -c backend/alembic.ini current
```

Resultado esperado:

```text
e7b3a9c2d4f1 (head)
```

Verificacion de diferencias:

```bash
alembic -c backend/alembic.ini check
```

Resultado esperado:

```text
No new upgrade operations detected.
```

## Supabase

La conexion se configura solo en `.env` local:

```env
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-1-REGION.pooler.supabase.com:5432/postgres?sslmode=require
```

No subir credenciales reales a Git.

## Transicion desde el MER en espanol

El MER inicial existia con nombres en espanol. La migracion
`e7b3a9c2d4f1` dejo tablas equivalentes en ingles y copia datos legacy si
encuentra tablas antiguas.

Mapa de transicion:

| Legacy espanol | Nuevo ingles |
| --- | --- |
| `usuario` | `users` |
| `encargado` | `guardians` |
| `cuidador` | `caregivers` |
| `adulto_mayor` | `older_adults` |
| `cuidador_adulto_mayor` | `caregiver_older_adults` |
| `perfil_medico` | `medical_profiles` |
| `historial_medico` | `medical_histories` |
| `examen_medico` | `medical_exams` |
| `detalle_examen` | `exam_details` |
| `parametro_examen` | `exam_parameters` |
| `medicamento` | `medication_catalog` |
| `tratamiento` | `treatments` |
| `tratamiento_medicamento` | `treatment_medications` |
| `cumplimiento_medicacion` | `medication_adherence_records` |
| `notificacion` | `notifications` |
| `destinatario_notificacion` | `notification_recipients` |
| `token_fcm` | `fcm_tokens` |

Los modelos legacy en espanol ya no son parte del backend activo. Si aparece una
base antigua con esas tablas, Alembic evita borrarlas accidentalmente mientras
se migra la informacion.

## Siguientes tareas para base de datos

1. Mantener nuevas migraciones dentro de `backend/alembic/versions`.
2. Revisar que todo nuevo modelo se importe en `backend/alembic/env.py`.
3. Conectar gradualmente perfil medico, cuidadores, historial y cumplimiento a
   sus tablas en ingles.
4. Antes de subir cambios, correr:

```bash
alembic -c backend/alembic.ini current
alembic -c backend/alembic.ini check
.venv/bin/python -m unittest discover -s backend/tests -v
```
