# Path to Senior — Salesforce Apex

Seguimiento de ejercicios y análisis de soluciones.

---

## Progreso

| # | Ejercicio | Estado |
|---|---|---|
| 1 | Sistema de Verificación de Emails | Completado |

---

## Ejercicio 1 — Sistema de Verificación de Emails

**Estado:** Completado

### Requisitos

- Scheduled Apex que dispara cada noche a las 11pm.
- Batch que procesa `Contact` con `Email_Verified__c = false` en chunks de 50.
- Callout simulado a una API de verificación usando `HttpCalloutMock`.
- Si el callout falla, un Finalizer loggea el error en `Integration_Error__c`.
- `finish()` encola un Queueable que envía un email de resumen.
- Publica un Platform Event `VerificationCompleted__e` con el resumen final.

### Clases entregadas

| Clase | Patrón | Estado |
|---|---|---|
| `SchedulerVerifyContact` | Schedulable | Correcto |
| `BatchVerifyContact` | Batchable + Stateful + AllowsCallouts | Correcto (tras correcciones) |
| `ServiceVerifyContact` | HTTP Callout | Correcto (tras correcciones) |
| `SyncFinalizer` | Finalizer | Implementado, huérfano en la solución final |
| `QueueVerifyContact` | Queueable | Correcto |
| `EndpointVerifyContactMock` | HttpCalloutMock | Correcto |
| `BatchVerifyContactTest` | Test | Correcto |
| `ServiceVerifyContactTest` | Test | Correcto |

### Bugs encontrados en revisión

**Críticos (no compilaban o fallaban en runtime):**

1. `BatchVerifyContact.finish()` referenciaba `contacts`, variable inexistente — error de compilación.
2. `ServiceVerifyContact` usaba `RestRequest`/`RestResponse` (API de endpoints entrantes) en lugar de `HttpRequest`/`Http`/`HttpResponse` (API de callouts salientes).
3. Faltaba `Database.AllowsCallouts` en el Batch — lanza `CalloutException` en runtime.
4. `verifyEmail()` creaba `Contact` sin `Id` y el `update` DML fallaba — se resolvió con un mapa `Email → Contact` del scope original.
5. Loop `for (String emailAddr : verifiedContacts)` siendo `verifiedContacts` un `List<Contact>` — error de tipo, no compilaba.

**De diseño:**

6. `System.attachFinalizer()` llamado desde el contexto de un Batch — los Finalizers solo funcionan adjuntados a un Queueable.
7. No había clase de test en la entrega inicial.

### Lo que estaba bien desde el inicio

- Estructura general correcta: el flujo Scheduler → Batch → Queueable → Platform Event es el adecuado.
- `Database.Stateful` para acumular estado entre chunks.
- `EndpointVerifyContactMock` implementado correctamente.
- `SyncFinalizer` con estructura válida y campos correctos en `Integration_Error__c`.
- `QueueVerifyContact` publicando el Platform Event y enviando el email.
- Cron expression `0 0 23 ? * *` correcta para las 11pm.

### Evaluación de nivel

**Junior+ / Mid en formación.**

Fortalezas: conocimiento de todos los patrones async de Salesforce (Batch, Queueable, Scheduled, Platform Events, Finalizer, HttpCalloutMock). El mapa mental es correcto.

Brecha principal: los bugs eran errores de API y variables inexistentes — indican que el código no se ejecutó en org antes de entregar. Un desarrollador Mid los habría detectado desplegando en sandbox.

Para llegar a Mid:
- Desplegar en sandbox y leer los errores antes de dar por terminado un ejercicio.
- Practicar governor limits: SOQL en loops, límites de callouts por transacción, DML parcial con `Database.update(list, false)`.
- Profundizar en testing: edge cases, chunks distintos, errores de DML parcial.
- Interiorizar los contextos de cada patrón async (qué puedes hacer en un Batch vs un Queueable vs un Future).
