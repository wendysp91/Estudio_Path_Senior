# Ejercicio: Sistema de Verificación de Emails

Ejercicio del temario **Path to Senior** — Salesforce Apex Asíncrono.

---

## Objetivo

Construir un sistema end-to-end de verificación de emails sobre el objeto `Contact`, combinando los principales patrones de Apex asíncrono de Salesforce.

---

## Requisitos del ejercicio

- Un **Scheduled Apex** que dispara cada noche a las 11pm.
- Lanza un **Batch** que procesa `Contact` con `Email_Verified__c = false` en chunks de 50.
- Para cada Contact hace un **callout simulado** a una API de verificación (usando `HttpCalloutMock`).
- Si el callout falla, un **Finalizer** loggea el error en `Integration_Error__c`.
- Al terminar el Batch, `finish()` encola un **Queueable** que envía un email de resumen.
- Publica un **Platform Event** `VerificationCompleted__e` con el resumen final.

---

## Arquitectura de la solución

```
SchedulerVerifyContact (Schedulable)
    └── BatchVerifyContact (Batchable + Stateful + AllowsCallouts)
            ├── execute() → ServiceVerifyContact (HTTP Callout)
            │       └── catch() → Integration_Error__c (log de errores)
            └── finish() → QueueVerifyContact (Queueable)
                    ├── Messaging.sendEmail() (email de resumen)
                    └── EventBus.publish(VerificationCompleted__e)
```

---

## Clases

### `SchedulerVerifyContact`
Implementa `Schedulable`. Lanza el batch con chunk de 50.

```
Cron: 0 0 23 ? * *  →  todos los días a las 23:00
```

Para programar desde la Developer Console:
```apex
System.schedule('Scheduler Verify Contact', '0 0 23 ? * *', new SchedulerVerifyContact());
```

---

### `BatchVerifyContact`
Implementa `Database.Batchable<SObject>`, `Database.Stateful` y `Database.AllowsCallouts`.

- `start()` — query de Contacts con `Email_Verified__c = false`.
- `execute()` — construye un mapa `Email → Contact` para resolver el Id original, llama al servicio de verificación y actualiza los que devuelven `verified`.
- `finish()` — encola el `QueueVerifyContact` con los contactos procesados.

`Database.Stateful` permite acumular `processedContacts` y `totalRecordsProcessed` a través de todos los chunks.

---

### `ServiceVerifyContact`
Encapsula el callout HTTP saliente a la API de verificación.

- Usa `HttpRequest` / `Http` / `HttpResponse` (API de callouts salientes de Apex).
- En caso de excepción, inserta un registro `Integration_Error__c` con el mensaje y el stack trace.
- Devuelve un `Map<String, String>` con `email → status`.

---

### `SyncFinalizer`
Implementa `Finalizer`. Diseñado para capturar excepciones no controladas de un Queueable y logearlas en `Integration_Error__c`.

> **Nota de diseño:** Los Finalizers en Salesforce solo funcionan adjuntados a un **Queueable** (vía `System.attachFinalizer()`), no a un Batch. En esta solución el manejo de errores del callout se resuelve directamente en el bloque `catch` de `ServiceVerifyContact`. La clase `SyncFinalizer` queda como referencia del patrón.

---

### `QueueVerifyContact`
Implementa `Queueable`. Recibe la lista de contactos verificados desde `finish()`.

1. Publica el Platform Event `VerificationCompleted__e` con el total de contactos y un mensaje de resumen.
2. Envía un email de resumen al administrador.

---

### `EndpointVerifyContactMock`
Implementa `HttpCalloutMock`. Simula la respuesta de la API de verificación para los tests.

- Parsea la lista de emails del body de la request.
- Devuelve `verified` para `mengana@emailin.com` y `not verified` para el resto.

---

## Tests

### `BatchVerifyContactTest`
- `@testSetup` inserta 3 Contacts con `Email_Verified__c = false`.
- Activa el Mock con `Test.setMock()`.
- Ejecuta el batch y verifica que solo `mengana@emailin.com` queda con `Email_Verified__c = true`.

### `ServiceVerifyContactTest`
- `testMakeCallout_Success` — verifica que con Mock activo el mapa de resultados se parsea correctamente.
- `testMakeCallout_Exception` — verifica que sin Mock (callout no permitido en test) la excepción es capturada y se inserta un `Integration_Error__c`.

---

## Objetos personalizados requeridos

| Objeto | Campos |
|---|---|
| `Contact` | `Email_Verified__c` (Checkbox) |
| `Integration_Error__c` | `Error_Message__c` (Text), `Stack_Trace__c` (Long Text), `Job_Type__c` (Text) |
| `VerificationCompleted__e` | `TotalContacts__c` (Number), `Message__c` (Text) |

---

## Conceptos demostrados

- `Schedulable` con expresión cron
- `Database.Batchable` + `Database.Stateful` + `Database.AllowsCallouts`
- Callouts HTTP salientes (`HttpRequest` / `Http` / `HttpResponse`)
- `HttpCalloutMock` para testing de callouts
- `Finalizer` (patrón de manejo de errores en Queueable)
- `Queueable` encadenado desde `finish()`
- Platform Events con `EventBus.publish()`
- `Messaging.SingleEmailMessage` para emails programáticos
