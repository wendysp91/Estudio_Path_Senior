# Excepciones en Apex — from scratch

---

## Qué es una excepción

Una excepción es una señal de que algo salió mal. Cuando se lanza, el código deja de ejecutarse en ese punto y sube por la cadena de llamadas buscando a alguien que la maneje.

```
método A llama a método B
método B llama a método C
método C lanza una excepción
↑ sube a B
↑ sube a A
↑ si nadie la atrapa → Salesforce la captura, hace rollback del chunk
```

---

## El flujo básico: `throw` y `catch`

```apex
// LANZAR = señalar que algo salió mal
throw new IllegalArgumentException('El email está vacío');

// ATRAPAR = reaccionar a esa señal
try {
    hazAlgo();
} catch (IllegalArgumentException e) {
    System.debug(e.getMessage()); // llega aquí si hazAlgo() lanzó esa excepción
}
```

El `try/catch` es una trampa. Si la excepción cae dentro de la trampa, tú la manejas. Si no hay trampa, sigue subiendo.

---

## Propagar vs. tragar

**Tragar** = atrapar la excepción y no hacer nada útil con ella. El flujo continúa como si no hubiera pasado nada.

```apex
try {
    HttpResponse res = http.send(req);
} catch (Exception e) {
    System.debug('hubo un error'); // ← TRAGADA. El método sigue, devuelve null o basura
}
// El código que llamó a esto no sabe que falló algo
```

**Propagar** = dejar que la excepción suba al que llamó, para que él decida.

```apex
// Opción A: simplemente no atraparla
public void execute() {
    List<Contact> result = svc.makeCallout(); // si lanza, sube automáticamente
}

// Opción B: atrapar, hacer algo (loggear), y relanzar
try {
    HttpResponse res = http.send(req);
} catch (AuthenticationException ae) {
    EventBus.publish(new Log_Error_Event__e(...)); // reacciono
    throw ae;                                      // y la propago igual
}
```

**La pregunta clave antes de escribir un `catch`:** ¿quién tiene que enterarse de que esto falló?
- Solo yo (este método) → atrapa y maneja.
- El que me llamó → propaga (no atrapes, o atrapa y relanza).

---

## Ejemplo de error real: excepción tragada por accidente

```apex
// CalloutErrorHandling
if (response.getStatusCode() == 401) {
    throw new AuthenticationException('401 Unauthorized'); // ← lanzada aquí
}

// En el mismo método, unas líneas abajo:
catch (AuthenticationException ae) {
    System.debug('Error de auth: ' + ae.getMessage()); // ← TRAGADA aquí
    return new List<Contact>();                         // ← devuelve lista vacía
}
```

`BatchErrorHandling.execute()` nunca se entera del 401. Para él, el callout simplemente devolvió una lista vacía y el chunk continúa. La excepción no sirvió para nada.

La corrección:

```apex
catch (AuthenticationException ae) {
    EventBus.publish(new Log_Error_Event__e(Error_Message__c = ae.getMessage())); // loggeo
    throw ae; // propago → execute() no la atrapa → chunk cancelado
}
```

---

## Cuándo crear una clase que extiende `Exception`

Usas una excepción custom cuando necesitas **distinguir** un tipo de error de otro para reaccionar diferente.

```apex
// Sin excepción custom: no puedes distinguir qué pasó
catch (Exception e) {
    // ¿fue timeout? ¿fue 401? ¿fue null pointer? No sé → no puedo reaccionar diferente
}

// Con excepción custom: cada error tiene su tipo
catch (AuthenticationException ae) {
    throw ae;                        // cancela el chunk
}
catch (System.CalloutException ce) {
    return new List<Contact>();      // continúa
}
catch (Exception e) {
    System.enqueueJob(...);          // recovery general
}
```

**Regla simple:** crea una excepción custom cuando el *comportamiento* ante ese error es distinto al de cualquier otra excepción que ya existe.

**Cómo se define:**

```apex
public class AuthenticationException extends Exception {}
// No necesita cuerpo. Hereda getMessage(), getCause(), etc. de Exception.
```

Si quieres agregarle datos extra:

```apex
public class AuthenticationException extends Exception {
    public Integer statusCode;

    public AuthenticationException(String msg, Integer code) {
        this(msg);              // llama al constructor de Exception
        this.statusCode = code;
    }
}

// Uso:
throw new AuthenticationException('Unauthorized', 401);
```

---

## Dónde definir la clase

**Inner class** → solo se usa desde esa clase o quien tenga acceso. Útil cuando la excepción es específica de un servicio:

```apex
public class CalloutErrorHandling {
    // ...
    public class AuthenticationException extends Exception {}
}

// Desde afuera se referencia con el nombre completo:
catch (CalloutErrorHandling.AuthenticationException ae) { ... }
```

**Top-level class** → reutilizable desde cualquier clase del org:

```apex
// AuthenticationException.cls
public class AuthenticationException extends Exception {}

// Desde cualquier lado:
catch (AuthenticationException ae) { ... }
```

Usa inner class cuando la excepción es propia de esa clase. Usa top-level cuando varios servicios pueden lanzarla.

---

## El orden de los `catch` importa

Apex evalúa los `catch` de arriba hacia abajo y entra al primero que coincide. Como `AuthenticationException extends Exception`, si pones `Exception` primero, nunca llega al específico:

```apex
// MAL — Exception lo atrapa todo, AuthenticationException nunca llega
catch (Exception e) { ... }
catch (AuthenticationException ae) { ... } // código muerto

// BIEN — específico primero, general al final
catch (AuthenticationException ae) { ... }
catch (System.CalloutException ce) { ... }
catch (Exception e) { ... }               // safety net
```

---

## Excepciones y transacciones en Batch

En un Batch, cada `execute()` es su propia transacción. Si una excepción sale sin atrapar del `execute()`, Salesforce hace **rollback de ese chunk** y el batch continúa con el siguiente.

```
execute(chunk 1) → excepción no atrapada → rollback chunk 1, batch sigue
execute(chunk 2) → ok → commit
execute(chunk 3) → ok → commit
```

Esto es exactamente "cancelar el chunk": la excepción propaga fuera de `execute()` y Salesforce se encarga del rollback. El batch completo no muere, solo ese chunk falla.

Por eso la `AuthenticationException` tiene que propagarse: para que Salesforce haga rollback del chunk con 401 mientras los demás chunks continúan.

---

## Resumen

| Quiero... | Hago... |
|---|---|
| Cancelar el chunk, batch continúa | Propagar excepción fuera de `execute()` |
| Loggear y continuar sin cancelar | Atrapar, loggear con PE, `return` |
| Loggear Y cancelar | Atrapar, loggear con PE, `throw` |
| Distinguir tipos de error | Crear excepción custom, atrapar por tipo |
| Safety net para lo inesperado | `catch (Exception e)` al final |
