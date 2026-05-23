# Dynamic Apex: guía completa con manzanitas

---

## Primero: ¿qué es Dynamic Apex?

Apex normal: **sabes de antemano** con qué objeto y qué campos vas a trabajar.

```apex
// Sabes que es Account, sabes que es Name
List<Account> accs = [SELECT Id, Name FROM Account WHERE Rating = 'Hot'];
```

Dynamic Apex: **no sabes en tiempo de compilación** con qué objeto o campos vas a trabajar. Lo descubres en tiempo de ejecución.

```apex
// El objeto y el campo llegan como String desde afuera
String objectName = 'Account';
String query = 'SELECT Id, Name FROM ' + objectName;
List<SObject> records = Database.query(query);
```

---

## La manzana del problema

Imagina que tienes una fábrica que solo hace **manzanas rojas** (Apex normal):

```apex
// La fábrica está "hardcodeada" para manzanas rojas
Account acc = new Account();
acc.Name = 'Manzana Roja';
```

Pero llega un cliente y dice: *"yo quiero manzanas verdes, amarillas, y a veces peras"*.

Con Apex normal tendrías que crear una fábrica por fruta. Con Dynamic Apex, construyes **una fábrica universal** que recibe el tipo de fruta como parámetro.

---

## Las 3 herramientas de Dynamic Apex

### 1. Schema Describe (el catálogo de la fábrica)

Sirve para **inspeccionar la metadata** en tiempo de ejecución: qué objetos existen, qué campos tienen, de qué tipo son.

```apex
// ¿Qué objetos existen en la org?
Map<String, Schema.SObjectType> allObjects = Schema.getGlobalDescribe();

// ¿Qué campos tiene Account?
Schema.DescribeSObjectResult accountDesc = Schema.SObjectType.Account;
Map<String, Schema.SObjectField> fields = accountDesc.fields.getMap();

// ¿Qué tipo de dato es el campo Rating?
Schema.DescribeFieldResult fieldDesc = fields.get('rating').getDescribe();
System.debug(fieldDesc.getType());      // PICKLIST
System.debug(fieldDesc.getLabel());     // 'Account Rating'
System.debug(fieldDesc.isUpdateable()); // true/false
```

**Manzanita:** Es como tener el manual completo de la fábrica. Puedes preguntar *"¿qué ingredientes tiene cada fruta?"* sin saber de antemano qué frutas existen.

---

### 2. Dynamic SOQL (la consulta que se arma en vuelo)

En vez de escribir la query literal, la construyes como un `String` y la ejecutas con `Database.query()`.

```apex
String objectName = 'Contact';
String filterField = 'LastName';
String filterValue = 'García';

String query = 'SELECT Id, FirstName, LastName FROM '
             + objectName
             + ' WHERE ' + filterField + ' = :filterValue';

List<SObject> results = Database.query(query);
```

**Manzanita:** Es como un chef que no sabe qué va a cocinar hasta que llega el pedido. Construye la receta sobre la marcha según lo que pide el cliente.

---

### 3. Dynamic DML (insertar/actualizar sin saber el objeto)

```apex
// Crear un registro de cualquier objeto recibido como String
String objectName = 'Account';
SObject record = Schema.getGlobalDescribe().get(objectName).newSObject();
record.put('Name', 'Cuenta Dinámica');
record.put('Rating', 'Hot');
insert record;
```

**Manzanita:** Es como una cinta transportadora universal. No está diseñada para manzanas ni peras: acepta cualquier fruta y la empaqueta igual.

---

## Cuándo USAR Dynamic Apex

### Caso 1: Utilidades genéricas (herramienta para cualquier objeto)

```apex
// Método que clona CUALQUIER registro de CUALQUIER objeto
public static SObject cloneRecord(SObject original) {
    Schema.SObjectType sObjType = original.getSObjectType();
    Map<String, Schema.SObjectField> fields = sObjType.getDescribe().fields.getMap();

    SObject clone = sObjType.newSObject();
    for (String fieldName : fields.keySet()) {
        if (fields.get(fieldName).getDescribe().isCreateable()) {
            clone.put(fieldName, original.get(fieldName));
        }
    }
    return clone;
}
```

Esto funciona con Account, Contact, Opportunity, o cualquier Custom Object. **Sin Dynamic Apex, necesitarías un método por cada objeto.**

---

### Caso 2: Configuración por Custom Metadata o Custom Settings

```apex
// El administrador configura qué objeto y campo usar, sin tocar código
Field_Mapping__mdt config = [SELECT Object_Name__c, Field_Name__c FROM Field_Mapping__mdt LIMIT 1];

String query = 'SELECT Id, ' + config.Field_Name__c
             + ' FROM ' + config.Object_Name__c
             + ' WHERE CreatedDate = TODAY';

List<SObject> records = Database.query(query);
```

**Manzanita:** El cliente cambia el pedido desde un panel de control, sin llamar al chef. El chef cocina lo que llegue.

---

### Caso 3: Validar Field-Level Security (FLS) en tiempo real

```apex
// Verificar que el usuario PUEDE ver el campo antes de mostrarlo
Schema.DescribeFieldResult fld = Schema.SObjectType.Account
    .fields.getMap()
    .get('AnnualRevenue')
    .getDescribe();

if (fld.isAccessible()) {
    // mostrar el campo
}
if (fld.isUpdateable()) {
    // permitir edición
}
```

Esto es crítico para **AppExchange** y cumplimiento de seguridad.

---

### Caso 4: ISV / Paquetes que se instalan en cualquier org

Si construyes un paquete que otros instalan, no sabes qué custom fields o custom objects tendrá cada org. Dynamic Apex te permite adaptarte.

---

## Cuándo NO usar Dynamic Apex (usa Apex normal)

| Situación | Por qué usar Apex normal |
|---|---|
| Sabes exactamente el objeto y los campos | Más legible, el compilador te avisa de errores |
| Performance crítica | Dynamic SOQL es más lento (no usa bind variables de forma óptima) |
| Lógica de negocio concreta | El código hardcodeado es más fácil de mantener y testear |
| Equipo junior | Dynamic Apex es más difícil de leer y debuggear |

**Manzanita:** Si siempre vas a hacer jugo de manzana, no necesitas una licuadora universal de 50 botones. Una licuadora de manzana es más simple, más rápida y no te equivocas de botón.

---

## El peligro más grande: SOQL Injection

Este es el tema más importante de Dynamic SOQL. Si concatenas input del usuario directamente, abres una vulnerabilidad grave.

```apex
// PELIGROSO — nunca hagas esto
String nombre = ApexPages.currentPage().getParameters().get('name');
String query = 'SELECT Id FROM Account WHERE Name = \'' + nombre + '\'';
// Si nombre = "' OR Id != null OR Name = '"
// la query devuelve TODOS los registros de la org
```

### Solución 1: `String.escapeSingleQuotes()`

```apex
String nombre = ApexPages.currentPage().getParameters().get('name');
String safeName = String.escapeSingleQuotes(nombre);
String query = 'SELECT Id FROM Account WHERE Name = \'' + safeName + '\'';
```

### Solución 2: bind variables (la mejor opción)

```apex
String nombre = ApexPages.currentPage().getParameters().get('name');
// La variable se usa directamente con : dentro del string
String query = 'SELECT Id FROM Account WHERE Name = :nombre';
List<SObject> results = Database.query(query);
// Apex escapa automáticamente el valor de nombre
```

**Manzanita:** Es como un cajero que no acepta billetes falsos. Si el cliente intenta meter un billete raro, la caja lo rechaza antes de procesarlo.

---

## Lo que necesitas saber de este tema (checklist)

```
[ ] Schema.getGlobalDescribe()         → lista todos los objetos de la org
[ ] SObjectType.getDescribe()          → describe un objeto (campos, nombre, etc.)
[ ] DescribeFieldResult                → describe un campo (tipo, label, FLS)
[ ] Database.query(String)             → ejecutar SOQL dinámico
[ ] SObject.put(field, value)          → asignar valor sin saber el campo en compile time
[ ] SObject.get(field)                 → leer valor sin saber el campo en compile time
[ ] Type.forName('ClassName')          → instanciar una clase por nombre (para estrategias)
[ ] String.escapeSingleQuotes()        → prevenir SOQL Injection
[ ] Bind variables en dynamic SOQL     → la forma más segura de pasar valores
```

---

## Resumen mental

```
¿Sabes el objeto y campos en tiempo de escritura?
    SÍ  →  Apex normal. Más simple, más seguro, el compilador te ayuda.
    NO  →  Dynamic Apex. Más poder, más responsabilidad.

Dynamic Apex se usa cuando:
    - Construyes herramientas genéricas (cualquier objeto)
    - La configuración viene de Custom Metadata / Settings
    - Necesitas verificar FLS en tiempo real
    - Estás en un paquete ISV

Siempre que uses Dynamic SOQL:
    - Usa bind variables (:variable) para valores del usuario
    - Nunca concatenes input sin escapar
```

> Dynamic Apex no es mejor ni peor que Apex normal. Es una herramienta diferente para un problema diferente. Un senior sabe cuándo sacarla.
