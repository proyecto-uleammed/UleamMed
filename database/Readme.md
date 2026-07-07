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
DATABASE_URL=postgresql+psycopg://user:pass@localhost:5432/uleammed
```

Usar valores reales solo en `.env` local o en secretos del entorno. No subir
usuarios, contrasenas ni URLs privadas al repositorio.

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

### Tabla oficial de autenticación del backend actual

- `users`

La tabla `users` es el contrato actual de autenticación del backend: registro,
inicio de sesión, perfil básico, refresh token y recuperación de contraseña.
Cuando `DATABASE_URL` apunta a Supabase, los usuarios quedan registrados en esta
tabla dentro de PostgreSQL/Supabase.

La tabla `usuario` se mantiene por compatibilidad con el MER de base de datos,
porque varias relaciones (`encargado`, `cuidador`, `adulto_mayor`,
`token_fcm`, etc.) dependen de `usuario.id_usuario`. No debe eliminarse hasta
que exista una migración formal que actualice esas llaves foráneas.

## Migraciones Alembic creadas

La secuencia de migraciones quedó organizada de la siguiente forma:

1. `899125d0bafd` - creación de la tabla inicial `users`
2. `6cf37e2123ce` - creación de la tabla `usuario`
3. `20b3513cc0dc` - creación de la tabla `encargado`
4. `34c12292dadd` - creación de la tabla `cuidador`
5. `4d76158bf7bf` - creación de las tablas principales restantes del MER
6. `b7a9f4e2c6d1` - creación de tokens temporales para recuperación de contraseña

## Estado validado

La base de datos quedó sincronizada con Alembic y la revisión actual validada es:

```powershell
alembic -c backend/alembic.ini current
```

Resultado esperado:

```text
b7a9f4e2c6d1 (head)
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

## Despliegue en Supabase (base compartida del equipo)

La estructura del MER ya fue desplegada en el proyecto de **Supabase** aplicando
las mismas migraciones de Alembic. La configuración ya está lista: `backend/alembic/env.py`
toma siempre la conexión desde `DATABASE_URL` (entorno o archivo `.env`), así que
**no** se escriben credenciales reales en Git.

Cuando `DATABASE_URL` apunta a Supabase, el backend de FastAPI guarda los
registros de autenticación en PostgreSQL/Supabase usando la tabla `users`. Esa
tabla sigue siendo el contrato actual de login, registro, perfil y recuperación
de contraseña. La tabla `usuario` pertenece al MER y queda disponible para la
integración funcional completa, pero todavía no reemplaza al flujo de auth.

### 1. Obtener la cadena de conexión de Supabase

1. Entra al proyecto en Supabase.
2. Ve a `Project Settings` -> `Database` -> `Connection string`.
3. Usa la pestaña **Session pooler** (puerto `5432`): funciona por IPv4 y admite
   las transacciones DDL de las migraciones. Evita el *Transaction pooler* (`6543`).
4. Adáptala al driver `psycopg` del proyecto (`postgresql+psycopg://`).

Formato final (reemplaza `PROJECT_REF`, `REGION` y `CONTRASENA`):

```env
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-1-REGION.pooler.supabase.com:5432/postgres?sslmode=require
```

Notas:

- `sslmode=require` es obligatorio: Supabase solo acepta conexiones cifradas.
- La contraseña es la de la base definida al crear el proyecto (o la reseteada en
  `Database` -> `Reset database password`). Nunca la subas al repositorio.

### 2. Configurar `.env` local (no se sube a Git)

```env
DATABASE_URL=postgresql+psycopg://postgres.PROJECT_REF:CONTRASENA@aws-1-REGION.pooler.supabase.com:5432/postgres?sslmode=require
```

### 3. Aplicar las migraciones sobre Supabase

```bash
alembic -c backend/alembic.ini current       # revision actual en Supabase
alembic -c backend/alembic.ini upgrade head  # crea/actualiza toda la estructura
alembic -c backend/alembic.ini current       # debe quedar en la ultima revision (head)
```

### 4. Verificar

En Supabase, `Table Editor` o `SQL Editor`, deben verse todas las tablas del MER
más la tabla de control `alembic_version` con el número de la última revisión.

### 5. Uso por el resto del equipo

Cada integrante solo pone la misma `DATABASE_URL` de Supabase en su `.env`. No
necesitan volver a correr `alembic -c backend/alembic.ini upgrade head`, salvo que se agreguen migraciones
nuevas; en ese caso, quien tenga la conexión ejecuta `alembic -c backend/alembic.ini upgrade head` una vez.

## Comandos útiles

Crear una migración nueva:

```powershell
alembic -c backend/alembic.ini revision --autogenerate -m "descripcion de la migracion"
```

Aplicar migraciones:

```powershell
alembic -c backend/alembic.ini upgrade head
```

Ver la revisión actual:

```powershell
alembic -c backend/alembic.ini current
```

## Decisión actual de integración

El backend queda conectado a Supabase/PostgreSQL usando `DATABASE_URL`.
Para autenticación se usará `users` como tabla oficial del MVP.

Pendiente para fases posteriores: conectar los módulos médicos reales
medicamentos, cuidadores, historial, notificaciones y cumplimiento con las
tablas del MER. Esa integración debe hacerse con migraciones nuevas y sin borrar
tablas que actualmente tengan llaves foráneas.
