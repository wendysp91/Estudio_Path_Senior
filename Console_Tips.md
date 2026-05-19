# Console & CLI Tips — Salesforce Apex

---

## SF CLI — sin necesidad de org

### Análisis estático con Apex Scanner
```bash
# Instalar el plugin (una sola vez)
sf plugins install @salesforce/sfdx-scanner

# Escanear todo el proyecto — detecta SOQL en loops, DML en loops, variables sin usar
sf scanner run --target force-app/

# Solo una clase
sf scanner run --target force-app/main/default/classes/LimitErrorCorrection.cls

# Output en tabla (más legible)
sf scanner run --target force-app/ --format table

# Solo reglas de performance (governor limits)
sf scanner run --target force-app/ --category "Performance"

# Solo reglas de buenas prácticas
sf scanner run --target force-app/ --category "Best Practices"
```

> Detecta: SOQL/DML en loops, string concat en loops, variables no usadas, métodos sin `@isTest`, catch vacíos.

---

## VS Code — sin deploy

### Apex Language Server (viene con la extensión Salesforce)
El LSP de Apex analiza el código en tiempo real sin necesidad de org:
- Subraya errores de tipo (`List<Order>` vs `List<Order__c>`)
- Marca variables no declaradas
- Autocompletado de métodos y campos

Requiere tener el proyecto configurado con `sfdx-project.json` (ya lo tienes).

### Apex Replay Debugger
Permite hacer debug de logs como si fuera un debugger normal (breakpoints, step over).
1. Captura un log desde tu org con `FINEST` level.
2. En VS Code: `SFDX: Launch Apex Replay Debugger with Current File`.

---

## Anonymous Apex — con org DE

Ejecutar desde VS Code con `Ctrl+Shift+P` → `SFDX: Execute Anonymous Apex`.

### Correr un Batch manualmente
```apex
Database.executeBatch(new BatchVerifyContact(), 50);
```

### Correr un Scheduled Job
```apex
System.schedule('Test Job', '0 0 23 ? * *', new SchedulerVerifyContact());
```

### Enqueue un Queueable
```apex
System.enqueueJob(new QueueVerifyContact(new List<Contact>()));
```

### Consulta rápida para verificar datos
```apex
List<Contact> contacts = [SELECT Id, Email, Email_Verified__c FROM Contact LIMIT 10];
System.debug(JSON.serializePretty(contacts));
```

---

## System.debug — patrones útiles

### Serializar cualquier objeto legible
```apex
System.debug(JSON.serializePretty(miObjeto));
System.debug(JSON.serializePretty(miMapa));
```

### Ver governor limits en tiempo real
```apex
System.debug('SOQL usadas: ' + Limits.getQueries() + ' / ' + Limits.getLimitQueries());
System.debug('DML usadas:  ' + Limits.getDMLStatements() + ' / ' + Limits.getLimitDMLStatements());
System.debug('CPU time:    ' + Limits.getCpuTime() + ' / ' + Limits.getLimitCpuTime());
System.debug('Heap:        ' + Limits.getHeapSize() + ' / ' + Limits.getLimitHeapSize());
```

> Ponlos al inicio y al final de un método para medir cuánto consume.

### Debug con nivel explícito (filtra mejor en los logs)
```apex
System.debug(LoggingLevel.ERROR, 'Algo salió mal: ' + e.getMessage());
System.debug(LoggingLevel.WARN,  'Revisar este caso: ' + orderId);
System.debug(LoggingLevel.INFO,  'Procesados: ' + totalRecords);
```

### Medir tiempo de ejecución
```apex
Long start = System.currentTimeMillis();
// ... código a medir ...
System.debug('Tiempo: ' + (System.currentTimeMillis() - start) + 'ms');
```

---

## Developer Console — con org DE

### Query Editor (SOQL rápido)
`Help → Open Developer Console → Query Editor`
```sql
SELECT Id, Email, Email_Verified__c FROM Contact WHERE Email_Verified__c = false LIMIT 10
```

### Filtrar logs útiles
En el panel de logs, filtra por `USER_DEBUG` para ver solo tus `System.debug()`.

### Ver límites de un test en el log
Busca `LIMIT_USAGE_FOR_NS` en el log — muestra todos los límites consumidos al final de la transacción.

---

## Workbench — alternativa online a la Developer Console
Herramienta web gratuita para conectar a cualquier org:
- Ejecutar SOQL/SOSL
- Inspeccionar metadata
- REST Explorer para probar APIs

---

## Dry-run mental — cuando no tienes org

Traza el código con datos concretos antes de entregarlo:

1. Define un input real: `List<Order__c> orders = [3 registros con Ids y Account__c distintos]`
2. Ejecuta cada línea en tu cabeza con esos valores
3. En cada acceso a un mapa o lista pregúntate: **¿puede ser null o vacío aquí?**
4. En cada DML pregúntate: **¿hay un callout después?**
5. En cada query pregúntate: **¿estoy dentro de un loop?**
