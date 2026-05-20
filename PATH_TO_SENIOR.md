# Path to Senior — Salesforce Apex

Seguimiento de ejercicios, análisis de soluciones y mapa de nivel.

---

## Progreso

| # | Ejercicio | Estado |
|---|---|---|
| 1 | Sistema de Verificación de Emails | Completado |
| 2 | Corrección de errores de Governor Limits | Completado |
| 3 | Manejo de errores en Batch con callouts | Completado |

---

## Mapa de niveles

### Qué define el nivel

El nivel no es sobre cuánto sabes — es sobre **qué tan seguido necesitas ayuda externa** para terminar una tarea.

---

### Junior

Necesita que le digan qué hacer y cómo hacerlo.

**Sabe:**
- Triggers, SOQL básico, DML, colecciones
- Algo de LWC o Aura
- Cómo crear clases y métodos
- Copiar patrones que funcionan

**Falla seguido en:**
- Bulkification — escribe SOQL en loops sin darse cuenta
- Elegir el patrón async correcto (Batch vs Queueable vs Future)
- Escribir tests que realmente prueban algo
- Leer un error de org y encontrar la causa raíz solo

**Señal clara:** entrega código que no compiló ni una vez antes de mostrarlo.

---

### Mid

Sabe qué hacer en la mayoría de casos. Necesita ayuda en decisiones de arquitectura o problemas nuevos.

**Sabe:**
- Todos los patrones async y cuándo usar cada uno
- Bulkification de memoria — no escribe SOQL en loops porque ya ni lo considera
- Escribir tests con cobertura real, no solo para llegar al 75%
- Debuggear errores de org: leer un stack trace, usar Anonymous Apex, interpretar logs
- Governor limits de memoria — sabe cuánto cuesta cada operación aproximadamente
- Integraciones básicas: callouts, Named Credentials, manejo de errores HTTP
- Seguridad básica: `with sharing`, CRUD/FLS, injection

**Señal clara:** puede tomar un requisito funcional y entregarlo sin revisión intermedia. Los bugs que tiene son de casos edge, no de sintaxis o API incorrecta.

**Diferencia clave con Junior:** no confunde `RestRequest` con `HttpRequest` porque ha integrado una API real y ha visto ese error explotar en producción.

---

### Senior

Sabe qué NO hacer. Diseña sistemas que otros pueden mantener.

**Sabe:**
- Cuándo una solución técnicamente correcta es un error de diseño
- Límites de plataforma que la documentación no dice — aprendidos a golpes
- Cómo un cambio en una clase afecta otras 10 cosas del org
- Estimación real: distingue lo que parece simple de lo que no lo es
- Traducir requisitos vagos del negocio en diseño técnico
- Qué tiene que estar en un code review para que no explote en 6 meses
- Metadata Dependencies, Release Management, CI/CD en Salesforce

**Señal clara:** rechaza soluciones. Dice "esto funciona pero en 6 meses va a ser un problema porque..." y tiene razón.

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

**Críticos:**

1. `BatchVerifyContact.finish()` referenciaba `contacts`, variable inexistente — error de compilación.
2. `ServiceVerifyContact` usaba `RestRequest`/`RestResponse` en lugar de `HttpRequest`/`Http`/`HttpResponse`.
3. Faltaba `Database.AllowsCallouts` en el Batch — lanza `CalloutException` en runtime.
4. `verifyEmail()` creaba `Contact` sin `Id` — el `update` DML fallaba. Resuelto con mapa `Email → Contact`.
5. Loop `for (String emailAddr : verifiedContacts)` con `verifiedContacts` siendo `List<Contact>` — error de tipo.

**De diseño:**

6. `System.attachFinalizer()` llamado desde Batch — solo funciona dentro de un Queueable.
7. Sin clase de test en la entrega inicial.

### Lo que estaba bien desde el inicio

- Flujo Scheduler → Batch → Queueable → Platform Event correcto.
- `Database.Stateful` para acumular estado entre chunks.
- `EndpointVerifyContactMock` implementado correctamente.
- `SyncFinalizer` con estructura válida y campos correctos.
- Cron expression `0 0 23 ? * *` correcta para las 11pm.

### Evaluación

**Junior+ / Mid en formación.** Conocimiento de todos los patrones correcto. Brecha: errores de API y variables inexistentes — el código no se ejecutó antes de entregar.

---

## Ejercicio 2 — Corrección de errores de Governor Limits

**Estado:** Completado

### Requisitos

Dado un `OrderProcessor` con 5 errores de límites, encontrarlos y corregirlos:

1. SOQL dentro de loop (query de `Account` por cada Order).
2. String concatenation con `+=` dentro de loop.
3. DML dentro de loop (`update order` por cada Order).
4. Callout dentro de loop (`h.send(req)` por cada Order).
5. DML antes de callout en la misma transacción.

### Clase entregada

`LimitErrorCorrection.cls`

### Scorecard

| Error | Identificado | Corregido |
|---|---|---|
| 1 — SOQL en loop | Sí (estructura presente) | Parcial — maps creados pero SOQL nunca ejecutadas |
| 2 — String concat en loop | Sí | Sí — `List<String>` + `String.join()` |
| 3 — DML en loop | Sí | Sí — `ordersToUpdate` fuera del loop |
| 4 — Callout en loop | Sí | Sí — un solo `h.send()` con todos los orders |
| 5 — DML antes de callout | Sí | Sí — `update` después del `h.send()` |

### Bug principal

Los mapas `accountMap` y `productMap` se inicializan pero nunca se pueblan con SOQL:

```apex
accountMap.put(order.Account__c, null);           // valor = null, sin query
productMap.put(order.Id, new List<Product2>());   // lista vacía, sin query
```

Resultado: `NullPointerException` en `accountMap.get(...).Name` y summary siempre vacío.

Lo que faltó:
```apex
Set<Id> accountIds = new Set<Id>();
for (Order__c order : orders) accountIds.add(order.Account__c);
Map<Id, Account> accountMap = new Map<Id, Account>(
    [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
);

Map<Id, List<Product__c>> productMap = new Map<Id, List<Product__c>>();
for (Order__c order : orders) productMap.put(order.Id, new List<Product__c>());
for (Product__c p : [SELECT Id, Price__c, Order__c FROM Product__c WHERE Order__c IN :orders]) {
    productMap.get(p.Order__c).add(p);
}
```

### Bugs secundarios

- `List<Order> ordersToUpdate` en lugar de `List<Order__c>` — type mismatch, no compila.
- `Map<Id, List<Product2>>` en lugar de `Map<Id, List<Product__c>>` — mismo problema.

### Lo que estaba bien

- Patrón de sacar DML del loop con lista acumuladora.
- Patrón de un solo callout con todos los orders serializados.
- Orden correcto: callout primero, DML después.
- `String.join()` como reemplazo del `+=` en loop.

### Evaluación

Consistente con el ejercicio 1 — **Junior+ / Mid en formación**. El patrón se repite: sabe qué estructura usar, falla en el detalle de ejecución. El NullPointerException en la línea 22 hubiera aparecido al primer run en org.

---

## Ejercicio 1.5 — Manejo de errores en Batch con callouts

**Estado:** Completado

### Requisitos

- Batch que procesa 10,000 Contacts con callout externo por chunk.
- Timeout → loggear y continuar (no cancelar el chunk).
- 401 Unauthorized → lanzar `AuthenticationException` y cancelar el chunk.
- DML falla en algún registro → modo parcial, loggear fallidos, continuar.
- El log debe sobrevivir aunque el chunk haga rollback → Platform Events.
- `finish()` reporta total procesados, exitosos y fallidos; notifica por email si hay más de 100 errores.
- Un Finalizer en un Queueable intermedio maneja el fallo catastrófico.

### Clases entregadas

| Clase | Patrón | Estado |
|---|---|---|
| `BatchErrorHandling` | Batchable + Stateful + AllowsCallouts | Correcto (tras correcciones) |
| `CalloutErrorHandling` | Servicio de callout con manejo de errores | Correcto (tras correcciones) |
| `QueueCalloutErrorHandling` | Queueable | Correcto (tras correcciones) |
| `FinalizerErrorHandling` | Finalizer | Correcto (ya tenía `implements Finalizer`) |

### Bugs encontrados en revisión

**De compilación:**

1. `CalloutErrorHandling` tenía una inner class `CalloutException extends Exception` que shadoweaba `System.CalloutException` — el `catch (CalloutException ce)` nunca atrapaba el timeout real del framework. Eliminada.
2. `QueueCalloutErrorHandling` — campo `contacts` no declarado; constructor vacío pero asignaba `this.contacts = contacts` (variable inexistente). Corregido con `private List<Contact> contacts` y constructor con parámetro.
3. `new QueueCalloutErrorHandling()` sin argumentos donde el constructor ya requería `List<Contact>`. Corregido a `new QueueCalloutErrorHandling(contacts)`.
4. `verifyEmail()` en `BatchErrorHandling` referenciaba `verifiedContacts` inexistente. Método eliminado (era código muerto).

**De lógica / diseño:**

5. `AuthenticationException` se lanzaba correctamente ante 401 pero se atrapaba en el mismo método y se tragaba (solo `System.debug`) — el chunk nunca se cancelaba. Corregido con `throw ae` para que propague hasta `execute()`.
6. Los errores de callout (timeout, genérico) usaban solo `System.debug` → log perdido en rollback. Reemplazado por `EventBus.publish(new Log_Error_Event__e(...))` en todos los catch.
7. `totalExitosos += contactsToUpdate.size()` contaba los que pasaron el callout, no los que pasaron el DML. Corregido incrementando `totalExitosos++` por cada `result.isSuccess()`.
8. `totalErrors += (scope.size() - contactsToUpdate.size())` no contaba los fallos de DML. Corregido: fallos de callout se cuentan antes del DML, fallos de DML dentro del loop de resultados.
9. `List<Contact> processedContacts` acumulada en `Database.Stateful` — con 10K registros y chunks de 200 puede alcanzar el límite de heap (12 MB). Eliminada: solo son necesarios los contadores numéricos.

### Lo que estaba bien desde el inicio

- `Database.AllowsCallouts` presente en el Batch.
- `Database.update(contactsToUpdate, false)` — modo parcial correcto.
- `EventBus.publish()` para errores de DML — concepto correcto, faltaba extenderlo a callouts.
- `System.attachFinalizer()` llamado dentro del Queueable — correcto (corrigió el error del Ejercicio 1 donde se llamaba desde el Batch).
- `FinalizerErrorHandling implements Finalizer` — ya estaba correcto.
- Estructura de `finish()` con email condicional a 100 errores — correcta.
- Detección del 401 con `response.getStatusCode() == 401` correcta.

### Evaluación

**Evolución visible respecto a ejercicios anteriores.** El Finalizer se colocó en el lugar correcto (Queueable, no Batch), y los conceptos de Platform Events y modo parcial de DML ya estaban en mente.

Los errores son más sutiles: no son errores de API incorrecta sino errores de flujo de control. El patrón que se repite es lanzar la excepción correcta pero atraparla en el mismo bloque sin relanzar, cortocircuitando el efecto que se buscaba. La `AuthenticationException` es el ejemplo exacto: lanzada bien, atrapada mal.

**Punto clave para internalizar:** cuando el objetivo de un `catch` es *reaccionar* al error (loggear, notificar), está bien atraparlo. Cuando el objetivo es *propagar el efecto* (cancelar el chunk, detener el flujo), hay que relanzar o no atrapar.

---

## Patrón común entre ejercicios

El conocimiento de los patrones es de nivel Mid. La ejecución tiene errores de Junior.

La distancia que falta no se cubre con más teoría:
- **Org real** (Developer Edition gratuita) para que los errores duelan y se aprendan.
- **Proyectos completos** con datos reales y restricciones reales.
- **Dry-run mental** con datos concretos cuando no hay org disponible: trazar cada línea con valores reales y preguntarse "¿puede ser null aquí?", "¿hay un callout después de este DML?".
