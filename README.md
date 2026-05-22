# Path to Senior — Salesforce Apex

Ejercicios del temario **Path to Senior** sobre Apex asíncrono, manejo de errores, testing y seguridad.

---

## Índice

- [Ejercicio 1.1 — Sistema de Verificación de Emails](#ejercicio-11--sistema-de-verificación-de-emails)
- [Ejercicio 1.2 — Corrección de Governor Limits](#ejercicio-12--corrección-de-governor-limits)
- [Ejercicio 1.5 — Manejo de Errores en Procesos Asíncronos](#ejercicio-15--manejo-de-errores-en-procesos-asíncronos)
- [Ejercicio 1.6 — Lead Enrichment con Dependency Injection](#ejercicio-16--lead-enrichment-con-dependency-injection)
- [Ejercicio 1.7 — Sistema de Acceso Regional](#ejercicio-17--sistema-de-acceso-regional)

---

## Ejercicio 1.1 — Sistema de Verificación de Emails

### Orden del ejercicio

Construir un sistema end-to-end de verificación de emails sobre el objeto `Contact`, combinando los principales patrones de Apex asíncrono:

- Un **Scheduled Apex** que dispara cada noche a las 11pm.
- Lanza un **Batch** que procesa `Contact` con `Email_Verified__c = false` en chunks de 50.
- Para cada Contact hace un **callout simulado** a una API de verificación.
- Si el callout falla, un **Finalizer** loggea el error en `Integration_Error__c`.
- Al terminar el Batch, `finish()` encola un **Queueable** que envía un email de resumen.
- Publica un **Platform Event** `VerificationCompleted__e` con el resumen final.

### Qué hace

Cada noche el scheduler lanza un batch que recorre todos los contactos sin email verificado. Por cada chunk hace un callout a una API externa que confirma si el email es válido. Si la verificación es positiva, marca el contacto. Al final, notifica al administrador por email y publica un evento con el resumen del proceso.

### Arquitectura

```
SchedulerVerifyContact (Schedulable)
    └── BatchVerifyContact (Batchable + Stateful + AllowsCallouts)
            ├── execute() → ServiceVerifyContact (HTTP Callout)
            │       └── catch() → Integration_Error__c (log de errores)
            └── finish() → QueueVerifyContact (Queueable)
                    ├── Messaging.sendEmail()
                    └── EventBus.publish(VerificationCompleted__e)
```

### Conceptos demostrados

- `Schedulable` con expresión cron
- `Database.Batchable` + `Database.Stateful` + `Database.AllowsCallouts`
- Callouts HTTP salientes con `HttpRequest` / `Http` / `HttpResponse`
- `HttpCalloutMock` para testing de callouts
- `Finalizer` como patrón de captura de errores en Queueable
- `Queueable` encadenado desde `finish()`
- Platform Events con `EventBus.publish()`
- `Messaging.SingleEmailMessage` para emails programáticos

### Clases

| Clase | Rol |
|---|---|
| `SchedulerVerifyContact` | Implementa `Schedulable`. Programa y lanza el batch cada noche. |
| `BatchVerifyContact` | Procesa los contactos en chunks. Acumula estado entre chunks con `Stateful`. |
| `ServiceVerifyContact` | Encapsula el callout HTTP. En caso de error, inserta un `Integration_Error__c`. |
| `SyncFinalizer` | Captura excepciones no controladas de un Queueable. Referencia del patrón `Finalizer`. |
| `QueueVerifyContact` | Publica el Platform Event de resumen y envía el email al administrador. |
| `EndpointVerifyContactMock` | Mock de la API de verificación para los tests. |

---

## Ejercicio 1.2 — Corrección de Governor Limits

### Orden del ejercicio

Dado un fragmento de código Apex que procesa una lista de órdenes (`Order__c`), identificar y corregir todas las violaciones de Governor Limits y errores de lógica que impiden que el código funcione correctamente en producción.

### Qué hace

El código original tenía múltiples problemas: SOQL construidos incorrectamente sobre listas (en lugar de sets), sobreescritura de los resultados de query con valores nulos, tipos inconsistentes entre la query y el mapa de resultados, y un callout HTTP ejecutado en el mismo contexto que operaciones DML sin respetar las restricciones de Apex.

### Conceptos demostrados

- Governor Limits: SOQL bulkification, límites de DML y callouts
- Separación obligatoria de callouts y DML en transacciones Apex
- Uso correcto de `Set<Id>` para coleccionar IDs antes de una query
- Consistencia de tipos entre queries y colecciones

### Clases

| Clase | Rol |
|---|---|
| `LimitErrorCorrection` | Versión de trabajo del procesador de órdenes con los límites corregidos. |

---

## Ejercicio 1.5 — Manejo de Errores en Procesos Asíncronos

### Orden del ejercicio

Implementar una estrategia completa de manejo de errores para un proceso batch con callouts, diferenciando el comportamiento según el tipo de error: errores recuperables (el chunk continúa), errores de autenticación (el chunk se cancela), y errores catastróficos (se activa un Finalizer). Usar Platform Events para que los logs persistan aunque la transacción haga rollback.

### Qué hace

Un batch procesa contactos haciendo callouts a un servicio externo. Según el tipo de fallo, el sistema reacciona de forma diferente: un timeout de red se registra y el chunk continúa; un 401 cancela el chunk completo; un error inesperado encola un Queueable de recuperación. Si ese Queueable también falla de forma catastrófica, el Finalizer notifica al administrador. Los logs se publican como Platform Events precisamente porque sobreviven el rollback de la transacción.

### Arquitectura

```
BatchErrorHandling (Batchable + Stateful + AllowsCallouts)
    └── execute() → CalloutErrorHandling
            ├── 200 OK       → actualiza Contacts (chunk continúa)
            ├── 401          → PE de log + AuthenticationException (cancela chunk)
            ├── CalloutEx    → PE de log + lista vacía (chunk continúa)
            └── Exception    → PE de log + QueueCalloutErrorHandling (recuperación)
                                    └── FinalizerErrorHandling
                                            └── fallo catastrófico → PE + email admin
```

### Conceptos demostrados

- Jerarquía de errores: recuperable vs. cancelación de chunk vs. catastrófico
- Platform Events como mecanismo de logging transaccionalmente seguro
- `Database.update` con `allOrNone = false` para fallos parciales de DML
- `Finalizer` adjunto a un Queueable para capturar excepciones no controladas
- Custom exceptions (`AuthenticationException`) para señalizar errores con semántica propia

### Clases

| Clase | Rol |
|---|---|
| `BatchErrorHandling` | Batch principal. Contabiliza éxitos y errores, envía email si los errores superan el umbral. |
| `CalloutErrorHandling` | Hace el callout y aplica la estrategia de error según el código de respuesta. |
| `QueueCalloutErrorHandling` | Queueable de recuperación para errores inesperados. Adjunta el Finalizer. |
| `FinalizerErrorHandling` | Captura fallos catastróficos del Queueable y notifica al administrador. |

---

## Ejercicio 1.6 — Lead Enrichment con Dependency Injection

### Orden del ejercicio

Implementar un servicio que enriquezca leads con datos de una API externa (empresa, industria), usando **Dependency Injection** para que el servicio sea testeable sin hacer callouts reales. Los tests deben cubrir: éxito, lead sin email, API que devuelve null, API que lanza excepción en un lead pero no en los demás, fallo parcial de DML, y carga de 200 registros.

### Qué hace

Al recibir una lista de leads, el servicio consulta una API externa por cada email. Si la API devuelve datos, actualiza `Company`, `Industry` y marca `Enriched__c = true`. Los errores de la API son aislados por lead: si falla uno, el resto se sigue procesando. Los fallos de DML son parciales, nunca propagan una excepción.

### Arquitectura

```
ExternalDataAPI (Interface)
    ├── [implementación real] → HTTP callout a API externa
    └── [mocks en test]  → MockAPI / NullAPI / CountingAPI / SelectiveFailingAPI

LeadEnrichmentService
    └── recibe ExternalDataAPI por constructor (DI)
    └── itera leads, llama api.lookupByEmail(), actualiza registros
    └── Database.update(leads, false) → fallos parciales sin excepción
```

### Conceptos demostrados

- **Dependency Injection** vía constructor para desacoplar la lógica del callout
- Mocking sin `HttpCalloutMock`: implementaciones de interfaz directamente en el test
- `Database.update` con `allOrNone = false` para tolerancia a fallos parciales de DML
- Tests aislados por escenario: null, excepción selectiva, DML parcial, bulk 200

### Clases

| Clase | Rol |
|---|---|
| `ExternalDataAPI` | Interfaz que abstrae la llamada a la API externa. |
| `LeadEnrichmentService` | Servicio de enriquecimiento. Recibe la API por constructor. |
| `TestLeadEnrichmentService` | Suite de tests con cuatro implementaciones mock de la interfaz. |

---

## Ejercicio 1.7 — Sistema de Acceso Regional

### Orden del ejercicio

Diseñar e implementar un sistema de acceso regional sobre el objeto `Client__c` (OWD = Private):

- Los usuarios solo ven clients de su región.
- Los gerentes regionales ven todos los clients de su región aunque no sean dueños.
- `ClientController` (`with sharing`) que devuelve clients usando `WITH USER_MODE`.
- `RegionalSharingService` (`without sharing`) que comparte con el Public Group de la región usando un Custom Share Reason `Regional_Access__c`. Al cambiar la región, elimina los shares anteriores y crea los nuevos.
- Trigger en `Client__c` que llama al servicio en `after insert` y `after update`.
- Tests que verifican que el usuario de Norte ve solo clients de Norte, y que al cambiar la región el sharing se reasigna correctamente.

### Qué hace

Cada región tiene un Public Group en Salesforce. Cuando se crea o modifica un `Client__c`, el trigger dispara el servicio que otorga acceso de lectura al grupo de la región del registro. Si el cliente cambia de región, el sistema revoca el acceso al grupo anterior y lo concede al nuevo. El controlador devuelve solo lo que el usuario tiene permitido ver, respetando sharing y seguridad de campo.

### Arquitectura

```
TriggerOnClient (after insert / after update)
    └── RegionalSharingService (without sharing)
            ├── insert → Client__Share con RowCause = Regional_Access__c
            └── update con cambio de región → delete share anterior + insert share nuevo

ClientController (with sharing)
    └── [SELECT ... WITH USER_MODE] → aplica sharing + FLS del usuario en contexto
```

### Conceptos demostrados

- **Apex Managed Sharing**: control programático del acceso a registros
- OWD = Private + Public Groups como modelo de seguridad regional
- Custom Share Reason (`Regional_Access__c`) para identificar shares gestionados por código
- `with sharing` + `WITH USER_MODE` como doble capa de seguridad en el controlador
- `without sharing` en el servicio de sharing (necesario para gestionar `Client__Share`)
- Mixed DML en tests: `System.runAs` para separar setup objects del DML regular
- `GroupMember` para asignar usuarios a grupos en tests

### Clases

| Clase | Rol |
|---|---|
| `ClientController` | Controlador `with sharing`. Expone los clients visibles al usuario actual vía `@AuraEnabled`. |
| `RegionalSharingService` | Gestiona los `Client__Share`. Crea y elimina shares según la región del registro. |
| `TestSharing` | Tests de integración: verifica visibilidad por región y reasignación al cambiar región. |
| `TriggerOnClient` | Trigger `after insert / after update` que invoca el servicio de sharing. |
