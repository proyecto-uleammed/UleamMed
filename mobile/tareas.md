# UleamMed — Tareas Frontend Android

> Product Backlog derivado de `Producto_Backlog_UleamMed_Frontend_Android`.
> Alcance: **solo Flutter/Dart** en `mobile/`. Backend, API, DB e infra quedan fuera.
>
> **Rama de referencia:** `Frontend` (PR #6 Eric Moreira — base offline).
> **Última revisión contra código:** 2026-07-06.

---

## Cómo usar este archivo


| Símbolo | Significado                                        |
| ------- | -------------------------------------------------- |
| `[x]`   | Hecho — cumple criterios de aceptación del backlog |
| `[~]`   | Parcial — hay avance pero faltan criterios         |
| `[ ]`   | Pendiente — sin implementar                        |


En ítems `[~]`, la sección **Falta** lista lo que falta para pasar a `[x]`.

**Definición de terminado (por historia):** pantalla navegable en Android, sin desbordes, validaciones locales, estados de carga/vacío/error, accesibilidad básica, comportamiento offline o mensaje correspondiente, prueba UI mínima o checklist, revisión del equipo.

---



## Resumen de avance


| Prioridad | Total  | Hecho `[x]` | Parcial `[~]` | Pendiente `[ ]` |
| --------- | ------ | ----------- | ------------- | --------------- |
| P0        | 41     | 6           | 18            | 17              |
| P1        | 18     | 1           | 4             | 13              |
| P2        | 4      | 0           | 0             | 4               |
| **Total** | **63** | **7**       | **22**        | **34**          |


**MVP P0 estimado:** ~35–40 % completado.

### Archivos clave actuales


| Área                               | Archivos                                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------------ |
| Navegación / shell                 | `lib/main.dart`, `lib/screens/home_screen.dart`                                                  |
| Acceso                             | `lib/screens/auth_screen.dart`, `lib/screens/password_recovery_screen.dart`                      |
| Perfil                             | `lib/screens/profile_screen.dart`                                                                |
| Medicamentos                       | `lib/screens/medications_screen.dart`                                                            |
| Citas                              | `lib/screens/appointments_screen.dart`                                                           |
| Emergencia                         | `lib/screens/emergency_screen.dart`                                                              |
| Actividades (extra, no en backlog) | `lib/screens/activities_screen.dart`                                                             |
| Tema / componentes                 | `lib/theme/app_theme.dart`, `lib/widgets/action_card.dart`                                       |
| API + local                        | `lib/services/api_service.dart`, `lib/services/local_store.dart`, `lib/models/local_models.dart` |
| Offline / sync                     | `lib/services/sync_service.dart`, `lib/services/connectivity_service.dart`                       |
| Notificaciones                     | `lib/services/notification_scheduler.dart` (stub)                                                |
| Pruebas                            | `test/widget_test.dart`, `test/api_service_test.dart`                                            |
| CI                                 | `.github/workflows/ci-flutter.yml`                                                               |


---



## Checklist MVP (10 condiciones de cierre)


| #   | Condición                                                          | Estado | Notas                                                               |
| --- | ------------------------------------------------------------------ | ------ | ------------------------------------------------------------------- |
| 1   | Registro, login y perfil médico básico                             | `[~]`  | Falta onboarding, términos en registro, perfil multipaso            |
| 2   | Crear medicamentos con dosis, frecuencia, horarios e instrucciones | `[~]`  | CRUD local listo; faltan horarios múltiples y pickers               |
| 3   | Próximas tomas y confirmar tomado/omitido/pospuesto                | `[~]`  | Confirmación en lista; falta dashboard de próximas 3 tomas y snooze |
| 4   | Historial básico de cumplimiento semanal                           | `[ ]`  | Solo % del día en Home                                              |
| 5   | Enfermedades, alergias, condiciones y consultas médicas            | `[~]`  | Texto libre en perfil; citas solo lectura demo                      |
| 6   | Pantalla de emergencia con datos clave                             | `[~]`  | Contactos locales; faltan alergias/enfermedades/meds en tarjeta     |
| 7   | Invitar/gestionar cuidador y permisos                              | `[ ]`  | Modelo en `local_models`; sin UI                                    |
| 8   | Offline, cola visual y emergencia local                            | `[~]`  | Store local listo; connectivity stub; sin pantalla de cola          |
| 9   | Términos, privacidad, consentimiento, bloqueo básico               | `[ ]`  | Solo switch “compartir con cuidadores”                              |
| 10  | Loading, empty, error, validaciones y a11y en pantallas            | `[~]`  | Inconsistente entre módulos                                         |


---



## Sprint 1 — Base visual, acceso y navegación



### PB-001 · Splash / pantalla de inicio clara · P0 · 2 pts · E01

- [~] **Estado: parcial**

**Criterios backlog:** logo/nombre UleamMed; detectar sesión; botones grandes iniciar sesión y registrarse; sin overflow en pantalla pequeña.

**Hecho:**

- `auth_screen.dart`: icono, título UleamMed, login/registro, modo demo.
- `main.dart`: restauración de sesión al abrir.

**Falta:**

- Pantalla splash/landing dedicada antes de auth.
- Estados visual loading/error en arranque.
- Botones con tamaño mínimo accesible documentado.

---



### PB-002 · Onboarding breve (máx. 3 pasos) · P0 · 3 pts · E01

- [ ] **Estado: pendiente**

**Criterios backlog:** explica medicamentos, recordatorios y cuidadores; opción omitir; texto grande y alto contraste.

**Falta:**

- Carousel o PageView de 3 pasos.
- Indicadores de página.
- Persistir “onboarding visto” en almacenamiento local.
- Botón “Omitir” y botón principal fijo.

---



### PB-003 · Iniciar sesión con correo y contraseña · P0 · 3 pts · E01

- [x] **Estado: hecho**

**Hecho:**

- `auth_screen.dart`: validación email/contraseña, ver/ocultar contraseña, loader, errores claros, botón deshabilitado mientras carga.
- Integración con `api_service.dart` (JWT).

---



### PB-004 · Registro de usuario principal · P0 · 5 pts · E01

- [~] **Estado: parcial**

**Criterios backlog:** nombre, correo, contraseña, confirmación; requisitos de contraseña; aceptar términos; éxito/error.

**Hecho:**

- Nombre, correo, contraseña (mín. 8 caracteres), toggle login/registro.

**Falta:**

- Campo confirmar contraseña.
- Lista visible de requisitos de contraseña.
- Checkbox de términos y privacidad (ver PB-055).
- Navegación post-registro a perfil médico inicial (PB-011).

---



### PB-007 · Sistema visual consistente (design system) · P0 · 5 pts · E02

- [~] **Estado: parcial**

**Hecho:**

- `app_theme.dart`: colores (`AppColors`), tipografía base, tema Material.
- `action_card.dart`: card reutilizable.
- Chips, badges y snackbars en varias pantallas.

**Falta:**

- Tokens documentados (espaciado, radios, elevaciones).
- Componentes base: botón primario/secundario, input, alerta, empty/error/loader globales.
- Modo oscuro (opcional según backlog).
- Carpeta `lib/widgets/` ampliada y guía de uso.

---



### PB-008 · Navegación inferior (5 módulos) · P0 · 3 pts · E02

- [ ] **Estado: pendiente**

**Criterios backlog:** Inicio, Medicamentos, Historial, Consultas, Perfil; iconos legibles; estado activo; máx. 5 opciones.

**Hecho:**

- Pantallas existen pero se abren desde cards en `home_screen.dart` (`Navigator.push`).

**Falta:**

- `Scaffold` con `NavigationBar` / `BottomNavigationBar`.
- Shell principal (`MainShell`) con rutas nombradas.
- Tab **Historial** (hoy no existe como módulo; está embebido en medicamentos).
- Estado activo persistente al cambiar de tab.

---



### PB-009 · Estados loading / empty / error globales · P0 · 3 pts · E02

- [~] **Estado: parcial**

**Hecho:**

- Medicamentos, citas y emergencia tienen loading, empty y error con reintentar.
- Snackbars de feedback en varias acciones.

**Falta:**

- Widgets reutilizables en `lib/widgets/` (`AppLoader`, `AppEmptyState`, `AppErrorState`).
- Aplicar patrón en Home, perfil, auth y futuro historial.
- Mensajes en lenguaje simple (sin jerga técnica).

---



### PB-011 · Crear perfil médico inicial · P0 · 5 pts · E03

- [~] **Estado: parcial**

**Hecho:**

- `profile_screen.dart`: fecha nacimiento, tipo sangre, condiciones, alergias, notas, contacto emergencia, guardado local.

**Falta:**

- Flujo multipaso (wizard) post-registro.
- Campo sexo (opcional según backlog).
- Campos obligatorios marcados con asterisco.
- Máscaras de entrada (fecha).
- Redirigir usuario nuevo desde registro a este flujo.

---



## Sprint 2 — Perfil, privacidad y medicamentos iniciales



### PB-005 · Recuperar contraseña · P1 · 2 pts · E01

- [x] **Estado: hecho**

**Hecho:**

- `password_recovery_screen.dart`: correo, solicitar código, código 6 dígitos, nueva contraseña, feedback visual.
- Prueba widget en `widget_test.dart`.

---



### PB-006 · Seleccionar / visualizar rol · P1 · 3 pts · E01

- [ ] **Estado: pendiente**

**Falta:**

- Modelo de rol en UI (paciente, cuidador, médico, admin).
- Menú adaptado por rol.
- Pantalla de acceso restringido.

---



### PB-010 · Ajustar tamaño de letra · P0 · 5 pts · E02

- [ ] **Estado: pendiente**

**Falta:**

- Preferencias locales (normal / grande / muy grande).
- `MediaQuery` / `TextScaler` o tema dinámico.
- Persistencia en `SharedPreferences` o `LocalStore`.
- Verificar que botones no se deformen en pantallas pequeñas.

---



### PB-012 · Editar datos personales y médicos · P0 · 3 pts · E03

- [x] **Estado: hecho**

**Hecho:**

- Carga datos existentes, guardar, validación, confirmación vía SnackBar, badge pendiente de sincronización.

---



### PB-013 · Registrar contactos de emergencia · P0 · 3 pts · E03

- [~] **Estado: parcial**

**Hecho:**

- Un contacto en perfil (nombre + teléfono).
- `emergency_screen.dart`: lista de contactos demo/local con relación y principal.

**Falta:**

- Formulario para agregar/editar/eliminar contactos.
- Validación de teléfono.
- Marcar contacto principal.
- Listado ordenado (principal primero).
- `Intent` de llamada Android (ver PB-048).

---



### PB-014 · Entender qué datos compartir con cuidadores · P0 · 3 pts · E03

- [~] **Estado: parcial**

**Hecho:**

- Switch `shareWithCaregivers` en perfil con texto explicativo.

**Falta:**

- Pantalla de consentimiento dedicada.
- Checkboxes por categoría (medicamentos, historial, consultas, alergias, emergencia).
- Resumen en lenguaje simple antes de aceptar.

---



### PB-016 · Ver lista de medicamentos actuales · P0 · 5 pts · E04

- [x] **Estado: hecho**

**Hecho:**

- Lista con cards grandes, nombre, dosis, horario, estado tomado/pendiente, badge sync, empty state.

---



### PB-017 · Registrar medicamento (nombre, dosis, frecuencia) · P0 · 8 pts · E04

- [~] **Estado: parcial**

**Hecho:**

- `_MedicationForm` en `medications_screen.dart`: nombre, dosis, frecuencia, hora, instrucciones, duración; guardado local.

**Falta:**

- Vista previa antes de guardar.
- Validación de dosis/frecuencia más estricta.
- Time picker nativo en lugar de solo texto.

---



### PB-018 · Configurar horarios y duración del tratamiento · P0 · 5 pts · E04

- [~] **Estado: parcial**

**Hecho:**

- Campos texto para hora, frecuencia y duración.

**Falta:**

- Varias horas al día (chips múltiples).
- `DatePicker` inicio/fin.
- Frecuencia diaria/semanal/personalizada.
- Resumen claro antes de guardar.

---



### PB-019 · Instrucciones de toma · P0 · 3 pts · E04

- [x] **Estado: hecho**

**Hecho:**

- Campo instrucciones en formulario; visible en card y detalle inline.

---



### PB-055 · Privacidad, términos y consentimiento · P0 · 3 pts · E12

- [ ] **Estado: pendiente**

**Falta:**

- Pantallas legales (términos, privacidad) accesibles desde registro y ajustes.
- Fecha de versión visible.
- Checkbox de aceptación en registro.
- Scroll obligatorio opcional.

---



## Sprint 3 — Medicamentos y recordatorios



### PB-015 · Resumen de información compartida · P1 · 3 pts · E03

- [ ] **Estado: pendiente**

**Falta:**

- Vista por cuidador con chips de categorías compartidas.
- Enlace a editar permisos (PB-044).

---



### PB-020 · Detalle de cada medicamento · P0 · 3 pts · E04

- [~] **Estado: parcial**

**Hecho:**

- Información en card expandida (dosis, horarios, instrucciones, chips).

**Falta:**

- Pantalla o bottom sheet de **detalle** dedicado.
- Historial corto del medicamento.
- Acciones editar / desactivar desde detalle.

---



### PB-021 · Editar, pausar o desactivar medicamento · P0 · 5 pts · E04

- [~] **Estado: parcial**

**Hecho:**

- Editar y eliminar vía formulario.

**Falta:**

- Estados activo / pausado / inactivo.
- Diálogo al desactivar.
- Motivo opcional al pausar.
- No eliminar historial visual al desactivar.

---



### PB-022 · Evitar duplicados al registrar · P1 · 3 pts · E04

- [ ] **Estado: pendiente**

**Falta:**

- Detección nombre + horario similar.
- Alert dialog con opción continuar bajo confirmación.

---



### PB-023 · Próximas tomas en pantalla de inicio · P0 · 5 pts · E05

- [~] **Estado: parcial**

**Hecho:**

- Card resumen “X de Y tomados” y porcentaje en Home.

**Falta:**

- Lista de **próximas 3 tomas** ordenadas por hora.
- Resaltar la más cercana.
- Botones tomado / posponer / omitir desde Home.
- Estado vacío “sin pendientes”.

---



### PB-024 · Permisos de notificación con explicación · P0 · 3 pts · E05

- [ ] **Estado: pendiente**

**Falta:**

- Flujo educativo antes de pedir permiso (`permission_handler` o API Android 13+).
- Pantalla si el usuario niega + guía a ajustes del sistema.
- No bloquear toda la app.

---



### PB-025 · Notificación local por cada toma · P0 · 5 pts · E05

- [ ] **Estado: pendiente**

**Hecho:**

- `notification_scheduler.dart` existe como **stub** (sin implementar).

**Falta:**

- Dependencia `flutter_local_notifications`.
- Canal Android, plantilla (nombre, dosis, hora).
- Programar/cancelar al crear/editar medicamento.
- Texto sin datos sensibles extra.

---



### PB-026 · Confirmar tomado / omitido / pospuesto · P0 · 8 pts · E05

- [~] **Estado: parcial**

**Hecho:**

- Tres acciones en card de medicamento; registro en `DoseConfirmation`; feedback SnackBar; historial corto en pantalla.

**Falta:**

- Bottom sheet de confirmación para acciones críticas (omitir).
- Feedback háptico opcional.
- Actualización optimista documentada.

---



## Sprint 4 — Historial, condiciones y consultas



### PB-027 · Posponer toma (10/15/30/60 min) · P0 · 3 pts · E05

- [~] **Estado: parcial**

**Hecho:**

- Acción “Posponer” registra `DoseStatus.postponed`.

**Falta:**

- Sheet con opciones 10, 15, 30, 60 minutos.
- Mostrar nueva hora reprogramada.
- Aviso si se pospone demasiadas veces.

---



### PB-029 · Historial de tomas · P0 · 5 pts · E06

- [~] **Estado: parcial**

**Hecho:**

- Lista de confirmaciones al final de `medications_screen.dart`.

**Falta:**

- Módulo/pantalla **Historial** propia (requiere PB-008).
- Agrupación por fecha.
- Chips de estado con color + texto.
- Empty state dedicado.

---



### PB-030 · Cumplimiento semanal · P0 · 5 pts · E06

- [ ] **Estado: pendiente**

**Hecho:**

- Porcentaje solo del día en Home.

**Falta:**

- Vista semanal: % tomado / omitido / pospuesto.
- Mensaje motivacional.
- Gráfico simple accesible.

---



### PB-031 · Historial por día, mes y año · P1 · 5 pts · E06

- [ ] **Estado: pendiente**

**Falta:**

- Componente calendario.
- Resumen al seleccionar día/mes.
- Persistir selección al volver.

---



### PB-032 · Filtrar historial · P1 · 3 pts · E06

- [ ] **Estado: pendiente**

**Falta:**

- Filtros por medicamento y estado.
- Botón limpiar; contador de resultados.

---



### PB-033 · Ver enfermedades, alergias y condiciones · P0 · 3 pts · E07

- [~] **Estado: parcial**

**Hecho:**

- Campos texto en perfil médico.

**Falta:**

- Secciones separadas con cards.
- Etiquetas de severidad.
- Acceso rápido desde emergencia.

---



### PB-034 · Registrar enfermedades / condiciones crónicas · P0 · 3 pts · E07

- [ ] **Estado: pendiente**

**Falta:**

- Modelo y formulario estructurado (nombre, fecha, nota, estado).
- Lista editable; no solo texto libre.

---



### PB-035 · Registrar alergias con nivel de riesgo · P0 · 3 pts · E07

- [ ] **Estado: pendiente**

**Falta:**

- Campos: alergia, severidad, reacción, notas.
- Select de severidad con color + texto.
- Validar severidad obligatoria.

---



### PB-037 · Listar consultas médicas · P0 · 3 pts · E08

- [~] **Estado: parcial**

**Hecho:**

- `appointments_screen.dart`: lista local/demo, loading/error/empty, resumen de cantidad.

**Falta:**

- Tabs próximas / pasadas.
- Búsqueda simple.
- Botón agregar en empty state.
- Datos editables (hoy son demo sembrados en API).

---



### PB-038 · Registrar consulta médica · P0 · 5 pts · E08

- [ ] **Estado: pendiente**

**Falta:**

- Formulario: especialidad/médico, fecha, hora, lugar, notas.
- `DatePicker` / `TimePicker`.
- Confirmación al guardar; persistencia local con sync pending.

---



## Sprint 5 — Cuidadores, emergencia y offline base



### PB-028 · Alertas al cuidador por toma no confirmada · P1 · 5 pts · E05

- [ ] **Estado: pendiente**

**Falta:**

- Centro de alertas (relacionado PB-045).
- Estados pendiente/resuelta; mock o API futura.

---



### PB-036 · Avisos médicos importantes en la app · P1 · 3 pts · E07

- [ ] **Estado: pendiente**

**Falta:**

- Banners de advertencia reutilizables para alergias severas.
- Visible en Home o perfil; no alarmista.

---



### PB-039 · Recordatorio de consulta médica · P1 · 3 pts · E08

- [ ] **Estado: pendiente**

**Falta:**

- Selector 1 día / 2 horas / personalizado.
- Notificación local de cita (depende PB-025).

---



### PB-040 · Detalle y notas de consulta · P1 · 3 pts · E08

- [~] **Estado: parcial**

**Hecho:**

- Card con médico, especialidad, fecha, lugar, notas (solo lectura).

**Falta:**

- Pantalla detalle.
- Botones editar / eliminar / marcar realizada.

---



### PB-041 · Invitar cuidador / familiar · P1 · 5 pts · E09

- [ ] **Estado: pendiente**

**Falta:**

- Formulario correo/teléfono.
- Explicación de qué verá el cuidador.
- Estado invitación pendiente/aceptada.

---



### PB-042 · Cuidador acepta invitación · P1 · 5 pts · E09

- [ ] **Estado: pendiente**

**Falta:**

- Pantalla de aceptación con paciente asociado.
- Consentimiento y confirmación de acceso.

---



### PB-043 · Dashboard cuidador · P1 · 5 pts · E09

- [ ] **Estado: pendiente**

**Falta:**

- Vista read-only: próximas tomas, alertas, contactos.
- Respeta permisos (PB-044).

---



### PB-044 · Asignar permisos por tipo de información · P0 · 5 pts · E09

- [~] **Estado: parcial**

**Hecho:**

- Modelo `CaregiverPermission` en `local_models.dart`.
- Lectura en `local_store.dart` para conteo sync.

**Falta:**

- UI con switches por categoría (medicamentos, historial, consultas, alergias, emergencia).
- Diálogo de confirmación al cambiar permisos.
- Pantalla de gestión de cuidadores.

---



### PB-046 · Pantalla de emergencia con datos clave · P0 · 5 pts · E10

- [~] **Estado: parcial**

**Hecho:**

- Acceso desde Home; banner alto contraste; lista de contactos; botón 911.

**Falta:**

- Acceso también desde Perfil.
- Mostrar alergias, enfermedades y medicamentos actuales en tarjeta de emergencia.
- Diseño de lectura rápida unificado.

---



### PB-047 · Emergencia disponible sin internet · P0 · 5 pts · E10

- [~] **Estado: parcial**

**Hecho:**

- Datos locales vía `LocalStore`; banner “disponible offline”.

**Falta:**

- Fecha de última actualización visible.
- Alergias/condiciones/meds en vista emergencia (no solo contactos).
- Probar flujo en modo avión.

---



### PB-049 · Banner sin conexión · P0 · 3 pts · E11

- [~] **Estado: parcial**

**Hecho:**

- `_OfflineStatusCard` en Home para cambios pendientes.

**Falta:**

- `ConnectivityService` real (hoy siempre `online`).
- Banner global no invasivo al perder/red recuperar internet.
- Diferenciar “sin red” vs “cambios pendientes de sync”.

---



## Sprint 6 — Sincronización visual, privacidad y calidad



### PB-045 · Centro de alertas del cuidador · P1 · 3 pts · E09

- [ ] **Estado: pendiente**

---



### PB-048 · Llamar a contacto de emergencia · P1 · 2 pts · E10

- [~] **Estado: parcial**

**Hecho:**

- Botones de teléfono en UI (911 y contactos).

**Falta:**

- `url_launcher` con `tel:`.
- Diálogo de confirmación antes de llamar.
- Guía si no hay número configurado.

---



### PB-050 · Registrar datos sin internet · P0 · 8 pts · E11

- [x] **Estado: hecho** *(Eric Moreira — PR #6)*

**Hecho:**

- `LocalStore` + modelos; CRUD medicamentos; perfil médico; confirmaciones; citas y contactos con `SyncStatus.pending`.

---



### PB-051 · Ver acciones pendientes de sincronizar · P0 · 5 pts · E11

- [~] **Estado: parcial**

**Hecho:**

- Contador en Home; botón sincronizar; mensaje vía `SyncService`.

**Falta:**

- Pantalla/lista de cola con acción, fecha y estado.
- Reintentar por ítem; estados error/synced.

---



### PB-053 · Bloqueo con PIN o biometría · P1 · 5 pts · E12

- [ ] **Estado: pendiente**

**Falta:**

- `local_auth` o PIN local.
- Pantalla de bloqueo al abrir app.

---



### PB-054 · Proteger sesión por inactividad · P1 · 3 pts · E12

- [ ] **Estado: pendiente**

**Falta:**

- Timeout configurable.
- Ocultar datos en app switcher (`secure` flag).

---



### PB-056 · Auditoría visual de acciones · P1 · 3 pts · E12

- [ ] **Estado: pendiente**

**Falta:**

- Pantalla de historial de cambios (mock local).
- Filtros por tipo de acción.

---



### PB-060 · Pruebas de navegación crítica · P0 · 5 pts · E14

- [~] **Estado: parcial**

**Hecho:**

- 10 tests en `widget_test.dart` + tests API; CI Flutter en PR.

**Falta:**

- Tests de: agregar medicamento, confirmar toma, emergencia, offline/sync, navegación por tabs (cuando exista PB-008).

---



### PB-061 · Rendimiento en gama media/baja · P0 · 5 pts · E14

- [ ] **Estado: pendiente**

**Falta:**

- Revisión de rebuilds, listas lazy, profiling documentado.

---



### PB-062 · Accesibilidad adultos mayores · P0 · 5 pts · E14

- [~] **Estado: parcial**

**Hecho:**

- Contraste razonable, botones grandes en varias pantallas, lenguaje simple.

**Falta:**

- Labels TalkBack en todos los controles.
- Prueba con fuente grande del sistema.
- Auditoría a11y documentada.

---



### PB-063 · Checklist de calidad por pantalla · P0 · 3 pts · E14

- [ ] **Estado: pendiente**

**Falta:**

- Plantilla QA en repo (puede ser sección al final de este archivo o `docs/qa-checklist.md`).
- Uso obligatorio antes de cerrar cada historia.

---



## Futuro — P2 (posterior al MVP)



### PB-052 · Resolver conflictos de datos · P2 · 8 pts · E11

- [ ] **Estado: pendiente**

---



### PB-057 · Vista médico/profesional · P2 · 8 pts · E13

- [ ] **Estado: pendiente**

---



### PB-058 · Panel administrador móvil · P2 · 8 pts · E13

- [ ] **Estado: pendiente**

---



### PB-059 · Reportes básicos admin · P2 · 5 pts · E13

- [ ] **Estado: pendiente**

---



## Extras fuera del backlog (revisar)


| Ítem                     | Archivo                  | Acción sugerida                                                              |
| ------------------------ | ------------------------ | ---------------------------------------------------------------------------- |
| Actividades del día      | `activities_screen.dart` | No está en backlog Miro. **Eliminar** o mover a P2 si el equipo lo confirma. |
| Modo demo en login       | `auth_screen.dart`       | Útil para desarrollo; ocultar en build release.                              |
| Card “Backend conectado” | `home_screen.dart`       | Orientado a dev; reemplazar por PB-049 en producción.                        |


---



## Orden sugerido de implementación (Carlos — UI/UX)

1. **PB-008** — Bottom navigation (desbloquea Historial y arquitectura).
2. **PB-002** — Onboarding.
3. **PB-004 + PB-055** — Registro completo con términos.
4. **PB-010** — Tamaño de letra.
5. **PB-009** — Componentes globales loading/empty/error.
6. **PB-023 + PB-029 + PB-030** — Dashboard tomas e historial.
7. **PB-038 + PB-037** — CRUD citas.
8. **PB-033–035 + PB-046/047** — Condiciones estructuradas + emergencia completa.
9. **PB-044 + PB-041–043** — Cuidadores.
10. **PB-024 + PB-025 + PB-027** — Notificaciones (coordinar con Eric).



## Coordinación con Eric (evitar duplicar)


| IDs                                                                | Tema                          | Responsable natural |
| ------------------------------------------------------------------ | ----------------------------- | ------------------- |
| PB-049, PB-051, PB-050                                             | Offline / sync / connectivity | Eric                |
| PB-024, PB-025, PB-039                                             | Notificaciones locales        | Eric                |
| PB-008, PB-002, PB-010, PB-023, PB-029–038, PB-044, PB-046, PB-055 | UI, navegación, pantallas     | Carlos              |


---



## Plantilla QA por pantalla (PB-063)

Copiar debajo de cada PR o historia al cerrarla:

```markdown
### QA — [Nombre pantalla] — PB-XXX
- [ ] Navegable en Android sin overflow
- [ ] Validaciones locales
- [ ] Loading / empty / error
- [ ] Accesibilidad básica (contraste, tamaño, labels)
- [ ] Comportamiento offline o mensaje claro
- [ ] flutter analyze sin issues
- [ ] flutter test (o prueba manual documentada)
- [ ] Revisión core
```

---



## Registro de cambios


| Fecha      | Autor           | Cambio                                                        |
| ---------- | --------------- | ------------------------------------------------------------- |
| 2026-07-06 | Carlos / agente | Creación inicial desde Product Backlog PDF vs rama `Frontend` |


