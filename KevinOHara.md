# Framework de Kevin O'Hara para Triggers en Salesforce

## El problema que resuelve (la manzana del caos)

Imagina que tienes una manzana (Account) y varios cocineros (developers) le hacen cosas distintos:

```apex
// Cocinero 1
trigger AccountTrigger on Account (before insert) { ... }

// Cocinero 2 (otro archivo!)
trigger AccountTrigger2 on Account (after update) { ... }

// Cocinero 3
trigger AccountTriggerFix on Account (before insert, after insert) { ... }
```

Resultado: **nadie sabe el orden, se pisan entre sí, es un desastre.** Eso es lo que soluciona el framework.

---

## La regla de oro (1 cuchillo por manzana)

> **Un solo trigger por objeto. Siempre.**

El trigger es solo el portero: recibe el evento y lo delega.

---

## La arquitectura completa

```
Account.trigger  ──►  AccountTriggerHandler  ──►  AccountService
   (portero)              (director)               (cocinero real)
```

---

## Capa 1: El Trigger (el portero)

```apex
trigger AccountTrigger on Account (
    before insert, before update, before delete,
    after insert,  after update,  after delete, after undelete
) {
    new AccountTriggerHandler().run();
}
```

Solo 2 líneas. **No hay lógica aquí.** Solo le pasa el balón al Handler.

---

## Capa 2: TriggerHandler base (la clase madre)

Esta clase se descarga una sola vez y nunca se toca. Todos los handlers la extienden.

```apex
public virtual class TriggerHandler {

    // Registro de handlers activos (para poder desactivarlos en tests)
    private static Set<String> bypassedHandlers = new Set<String>();

    public void run() {
        if (isBypassed(getHandlerName())) return; // ¿está desactivado?

        if (Trigger.isBefore) {
            if (Trigger.isInsert)  beforeInsert();
            if (Trigger.isUpdate)  beforeUpdate();
            if (Trigger.isDelete)  beforeDelete();
        } else {
            if (Trigger.isInsert)   afterInsert();
            if (Trigger.isUpdate)   afterUpdate();
            if (Trigger.isDelete)   afterDelete();
            if (Trigger.isUndelete) afterUndelete();
        }
    }

    // Métodos vacíos que cada Handler sobreescribe según necesite
    protected virtual void beforeInsert()   {}
    protected virtual void beforeUpdate()   {}
    protected virtual void beforeDelete()   {}
    protected virtual void afterInsert()    {}
    protected virtual void afterUpdate()    {}
    protected virtual void afterDelete()    {}
    protected virtual void afterUndelete()  {}

    // Para desactivar un handler desde tests
    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }
    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }
    private static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }
    private String getHandlerName() {
        return String.valueOf(this).split(':')[0];
    }
}
```

---

## Capa 3: Tu Handler (el director de orquesta)

```apex
public class AccountTriggerHandler extends TriggerHandler {

    // Casteamos los registros aquí, una sola vez
    private List<Account> newAccounts;
    private Map<Id, Account> oldMap;

    public AccountTriggerHandler() {
        this.newAccounts = (List<Account>) Trigger.new;
        this.oldMap      = (Map<Id, Account>) Trigger.oldMap;
    }

    // Solo sobreescribes los contextos que necesitas
    override protected void beforeInsert() {
        AccountService.setDefaultValues(newAccounts);
    }

    override protected void afterInsert() {
        AccountService.sendWelcomeEmail(newAccounts);
    }

    override protected void afterUpdate() {
        AccountService.syncToExternalSystem(newAccounts, oldMap);
    }
}
```

---

## Capa 4: El Service (el cocinero)

```apex
public class AccountService {

    public static void setDefaultValues(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.Rating == null) acc.Rating = 'Cold';
        }
    }

    public static void sendWelcomeEmail(List<Account> accounts) {
        // lógica de email...
    }

    public static void syncToExternalSystem(
        List<Account> accounts,
        Map<Id, Account> oldMap
    ) {
        List<Account> changed = new List<Account>();
        for (Account acc : accounts) {
            if (acc.Phone != oldMap.get(acc.Id).Phone) {
                changed.add(acc);
            }
        }
        // llamar callout, encolar job, etc.
    }
}
```

---

## Por qué esto es "senior"

| Junior | Senior (O'Hara) |
|---|---|
| Lógica dentro del trigger | Trigger = solo portero |
| Múltiples triggers por objeto | Un trigger por objeto |
| `if (Trigger.isBefore && Trigger.isInsert)` en todas partes | El framework lo maneja |
| Imposible desactivar en tests | `TriggerHandler.bypass('AccountTriggerHandler')` |
| Un archivo de 500 líneas | Responsabilidades separadas, testeable por capas |

---

## El truco más senior: bypass en tests

```apex
@isTest
static void testSomething() {
    // Desactivo el trigger para probar solo el service
    TriggerHandler.bypass('AccountTriggerHandler');

    insert new Account(Name = 'Test');

    TriggerHandler.clearBypass('AccountTriggerHandler');
}
```

Esto te permite probar cada capa **aislada**, sin que los triggers vecinos interfieran.

---

## Resumen

- **Trigger** → portero tonto, solo llama al handler
- **TriggerHandler base** → clase madre que enruta cada contexto al método correcto
- **AccountTriggerHandler** → director que delega en el service
- **AccountService** → el único que cocina, testeable sin trigger

> Cada quien hace solo su trabajo. Eso es diseño senior.
