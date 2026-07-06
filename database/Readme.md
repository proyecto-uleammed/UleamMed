# Base de Datos - UleamMed

## Responsable del módulo

Este módulo fue actualizado para dejar implementada la estructura principal de base de datos del proyecto en PostgreSQL, junto con su sincronización por migraciones usando Alembic.

## Stack utilizado

- PostgreSQL
- SQLAlchemy
- Alembic
- psycopg
- DBeaver para validación visual de tablas, claves primarias y claves foráneas

## Configuración local usada

```env
DATABASE_URL=postgresql+psycopg://uleammed_user:123@localhost:5432/uleammed_db
```

## Trabajo realizado

Se implementaron los modelos ORM en `backend/models` y se generaron las migraciones necesarias para sincronizar la estructura de la base de datos con Alembic.

### Tablas implementadas del MER

- `usuario`
- `encargado`
- `cuidador`
- `adulto_mayor`
- `cuidador_adulto_mayor`
- `perfil_medico`
- `historial_medico`
- `examen_medico`
- `detalle_examen`
- `parametro_examen`
- `medicamento`
- `tratamiento`
- `tratamiento_medicamento`
- `cumplimiento_medicacion`
- `notificacion`
- `destinatario_notificacion`
- `token_fcm`

### Tabla heredada del prototipo inicial

- `users`

La tabla `users` pertenece al backend inicial de prueba. La tabla real del MER aprobada para usuarios del sistema es `usuario`.

## Migraciones Alembic creadas

La secuencia de migraciones quedó organizada de la siguiente forma:

1. `899125d0bafd` - creación de la tabla inicial `users`
2. `6cf37e2123ce` - creación de la tabla `usuario`
3. `20b3513cc0dc` - creación de la tabla `encargado`
4. `34c12292dadd` - creación de la tabla `cuidador`
5. `4d76158bf7bf` - creación de las tablas principales restantes del MER

## Estado validado

La base de datos quedó sincronizada con Alembic y la revisión actual validada es:

```powershell
alembic current
```

Resultado esperado:

```text
4d76158bf7bf (head)
```

## Relaciones validadas en PostgreSQL

De acuerdo con la verificación realizada en DBeaver, las claves foráneas principales quedaron registradas correctamente:

- `adulto_mayor.id_encargado -> encargado.id_encargado`
- `adulto_mayor.id_usuario -> usuario.id_usuario`
- `cuidador.id_usuario -> usuario.id_usuario`
- `cuidador_adulto_mayor.id_adulto_mayor -> adulto_mayor.id_adulto_mayor`
- `cuidador_adulto_mayor.id_cuidador -> cuidador.id_cuidador`
- `cumplimiento_medicacion.id_tratamiento_medicamento -> tratamiento_medicamento.id_tratamiento_medicamento`
- `destinatario_notificacion.id_notificacion -> notificacion.id_notificacion`
- `destinatario_notificacion.id_usuario -> usuario.id_usuario`
- `detalle_examen.id_examen -> examen_medico.id_examen`
- `encargado.id_usuario -> usuario.id_usuario`
- `examen_medico.id_historial -> historial_medico.id_historial`
- `historial_medico.id_adulto_mayor -> adulto_mayor.id_adulto_mayor`
- `parametro_examen.id_detalle -> detalle_examen.id_detalle`
- `perfil_medico.id_adulto_mayor -> adulto_mayor.id_adulto_mayor`
- `token_fcm.id_usuario -> usuario.id_usuario`
- `tratamiento.id_adulto_mayor -> adulto_mayor.id_adulto_mayor`
- `tratamiento_medicamento.id_medicamento -> medicamento.id_medicamento`
- `tratamiento_medicamento.id_tratamiento -> tratamiento.id_tratamiento`

## Claves primarias verificadas

En DBeaver también se verificó la existencia de claves primarias para las tablas principales:

- `adulto_mayor.id_adulto_mayor`
- `cuidador.id_cuidador`
- `cuidador_adulto_mayor.id_relacion`
- `cumplimiento_medicacion.id_cumplimiento`
- `destinatario_notificacion.id_destinatario`
- `detalle_examen.id_detalle`
- `encargado.id_encargado`
- `examen_medico.id_examen`
- `historial_medico.id_historial`
- `medicamento.id_medicamento`
- `notificacion.id_notificacion`
- `parametro_examen.id_parametro`
- `perfil_medico.id_perfil`
- `token_fcm.id_token`
- `tratamiento.id_tratamiento`
- `tratamiento_medicamento.id_tratamiento_medicamento`
- `users.id`
- `usuario.id_usuario`

## Prueba de datos

Se validó también inserción y visualización de datos en la tabla `cumplimiento_medicacion`. En la revisión mostrada en DBeaver aparece al menos un registro de prueba con:

- `id_cumplimiento = 1`
- `id_tratamiento_medicamento = 1`
- `fecha_programada = 2026-07-04`
- `hora_programada = 08:00:00`
- `fecha_hora_real = NULL`
- `estado = pendiente`

## Evidencias visuales

Las capturas revisadas muestran:

1. La lista de claves foráneas entre tablas del MER.
2. La lista de claves primarias registradas en PostgreSQL.
3. Una consulta de prueba sobre `cumplimiento_medicacion` con datos visibles.

Nota: las capturas fueron compartidas durante la revisión, pero todavía no existen como archivos dentro del repositorio. Si luego se guardan en una carpeta del proyecto, este README puede enlazarlas directamente.

## Subir la base de datos a Supabase (base compartida del equipo)

El objetivo es aplicar exactamente las mismas migraciones de Alembic sobre el
proyecto de Supabase, para que todo el equipo use la misma estructura de tablas.
La configuración ya está preparada: `alembic/env.py` toma la conexión desde la
variable `DATABASE_URL` (entorno o archivo `.env`), por lo que **no** hay que
escribir credenciales dentro de `alembic.ini`.

### 1. Obtener la cadena de conexión de Supabase

1. Entra a tu proyecto en Supabase.
2. Ve a `Project Settings` -> `Database` -> `Connection string`.
3. Copia la cadena. Para migraciones se recomienda el **Session pooler**
   (puerto `5432`), que funciona bien con IPv4 y con DDL/migraciones.
4. Adapta la cadena al driver `psycopg` que usa el proyecto (`postgresql+psycopg://`).

Formato final esperado (reemplaza `PROJECT_REF`, `REGION` y `CONTRASENA`):

```env
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-0-REGION.pooler.supabase.com:5432/postgres?sslmode=require
```

Notas:

- La contraseña es la de la base de datos que definiste al crear el proyecto en
  Supabase (o la que reseteaste en `Database` -> `Reset database password`).
- `sslmode=require` es obligatorio: Supabase solo acepta conexiones cifradas.
- Usa el **Session pooler (5432)** para migraciones. Evita el *Transaction
  pooler* (`6543`) porque no maneja bien transacciones DDL de Alembic.

### 2. Configurar `.env` local (no se sube a Git)

```env
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-0-REGION.pooler.supabase.com:5432/postgres?sslmode=require
```

El archivo `.env` está en `.gitignore`, así que la contraseña de Supabase nunca
se versiona. Toma como referencia `.env.example`.

### 3. Aplicar las migraciones sobre Supabase

Desde la raíz del repositorio, con el entorno virtual activo:

```bash
# Verifica a qué base apunta y en qué revisión está (debería estar vacía la primera vez)
alembic current

# Crea toda la estructura del MER en Supabase
alembic upgrade head

# Confirma que quedó en la última revisión
alembic current   # -> 4d76158bf7bf (head)
```

Alternativa sin editar `.env` (pasando la variable solo para ese comando):

```bash
DATABASE_URL='postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-0-REGION.pooler.supabase.com:5432/postgres?sslmode=require' \
alembic upgrade head
```

### 4. Verificar en Supabase

En el panel de Supabase, `Table Editor` o `SQL Editor`, deberías ver todas las
tablas del MER (`usuario`, `encargado`, `cuidador`, `adulto_mayor`, etc.) más la
tabla de control `alembic_version` con el valor `4d76158bf7bf`.

### 5. Que el resto del equipo la use

Cada integrante solo necesita poner la misma `DATABASE_URL` de Supabase en su
`.env`. No deben volver a correr `alembic upgrade head` salvo que existan
migraciones nuevas: la estructura ya vive en Supabase compartida.

> Importante: nunca subas el `.env` ni la contraseña de Supabase al repositorio.
> Si la contraseña se filtra, resetéala desde `Project Settings` -> `Database`.

## Comandos útiles

Crear una migración nueva:

```powershell
alembic revision --autogenerate -m "descripcion de la migracion"
```

Aplicar migraciones:

```powershell
alembic upgrade head
```

Ver la revisión actual:

```powershell
alembic current
```

## Pendiente para integración completa

La estructura de base de datos ya está implementada y sincronizada. Lo que queda pendiente del lado de backend es adaptar los endpoints y servicios que todavía usan la tabla temporal `users`, para que trabajen con la tabla `usuario` y con las relaciones reales del MER.