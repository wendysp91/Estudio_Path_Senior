# Ejercicio 2 — SOSL y SOQL

## SOSL: Búsqueda con FIND

Buscar "González" en campos de nombre, devolviendo Contact y Lead con límite de 50 por objeto.

```sosl
FIND {González} IN NAME FIELDS
RETURNING
    Contact(Id, LastName LIMIT 50),
    Lead(Id, LastName, Company LIMIT 50)
```

**Puntos clave:**
- `IN NAME FIELDS` busca en FirstName, LastName, Name, etc.
- `LIMIT` se declara dentro del paréntesis de cada objeto para limitar por separado.
- La búsqueda no es sensible a diacríticos: `Gonzalez` también matchea `González`.

---

## SOQL: Account con más de 3 Opportunities cerradas ganadas

### Opción A — Aggregate (devuelve AccountId + conteo)

```soql
SELECT AccountId, COUNT(Id)
FROM Opportunity
WHERE StageName = 'Closed Won'
GROUP BY AccountId
HAVING COUNT(Id) > 3
```

### Opción B — Semi-join (devuelve campos de Account)

```soql
SELECT Id, Name
FROM Account
WHERE Id IN (
    SELECT AccountId
    FROM Opportunity
    WHERE StageName = 'Closed Won'
    GROUP BY AccountId
    HAVING COUNT(Id) > 3
)
```

**Errores comunes a evitar:**

| Incorrecto | Correcto |
|---|---|
| `Stage` | `StageName` |
| `'Close Won'` | `'Closed Won'` |
| `count()` en subquery + `WHERE count > 3` | `GROUP BY` + `HAVING COUNT(Id) > 3` |

---

## Subquery vs Semi-join

| Pregunta | Técnica |
|---|---|
| ¿Necesito acceder a los registros hijos en Apex? | Subquery en `SELECT` |
| ¿Solo necesito filtrar el padre? | Semi-join en `WHERE IN` |
| ¿Necesito filtrar por un agregado (`> 3`)? | Semi-join con `HAVING` |

### Subquery — para leer datos del hijo

```soql
SELECT Id, Name,
       (SELECT Id, StageName FROM Opportunities)
FROM Account
```

Usas esto cuando en Apex vas a iterar sobre los hijos:

```apex
for (Account acc : accounts) {
    for (Opportunity opp : acc.Opportunities) { ... }
}
```

### Semi-join — para filtrar sin leer el hijo

```soql
SELECT Id, Name
FROM Account
WHERE Id IN (
    SELECT AccountId FROM Opportunity
    WHERE StageName = 'Closed Won'
)
```

Las Opportunities no aparecen en el resultado, solo sirvieron como condición de filtro. Más eficiente cuando no necesitas los datos del hijo.
