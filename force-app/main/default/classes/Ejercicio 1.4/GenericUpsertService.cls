public class GenericUpsertService {

    public class UpsertException extends Exception {}

    /**
     * Upserts a list of payloads against any SObject.
     *
     * @param objectName      API name of the target SObject
     * @param externalIdField API name of the external-ID field (null → Id-based upsert)
     * @param payloads        Each map is one record; keys are field API names (case-insensitive)
     */
    public static void upsertRecords(
        String objectName,
        String externalIdField,
        List<Map<String, Object>> payloads
    ) {
        // ── 1. Validate object exists ─────────────────────────────────────────
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        if (sObjType == null) {
            throw new UpsertException('Object does not exist: ' + objectName);
        }
        Map<String, Schema.SObjectField> fieldMap =
            sObjType.getDescribe().fields.getMap();

        // ── 2. Validate external-ID field and pre-check existing records ──────
        Schema.SObjectField extIdToken = null;
        if (String.isNotBlank(externalIdField)) {
            extIdToken = fieldMap.get(externalIdField.toLowerCase());
            if (extIdToken == null) {
                throw new UpsertException(
                    'External-ID field not found on ' + objectName + ': ' + externalIdField
                );
            }
            // Pre-query with USER_MODE so FLS and sharing rules apply
            logPreUpsertSummary(objectName, externalIdField, payloads);
        }

        // ── 3. Build SObjects dynamically ─────────────────────────────────────
        List<SObject> records = buildRecords(sObjType, fieldMap, payloads);
        if (records.isEmpty()) return;

        // ── 4. Partial upsert (allOrNone = false) ─────────────────────────────
        Database.UpsertResult[] results = (extIdToken != null)
            ? Database.upsert(records, extIdToken, false)
            : Database.upsert(records, false);

        // ── 5. Log failures without cancelling successes ──────────────────────
        logFailures(results, records);
    }

    // ── private helpers ──────────────────────────────────────────────────────

    private static List<SObject> buildRecords(
        Schema.SObjectType sObjType,
        Map<String, Schema.SObjectField> fieldMap,
        List<Map<String, Object>> payloads
    ) {
        List<SObject> records = new List<SObject>();

        for (Map<String, Object> payload : payloads) {
            SObject record = sObjType.newSObject();

            for (String rawKey : payload.keySet()) {
                Schema.SObjectField fieldToken = fieldMap.get(rawKey.toLowerCase());

                // Skip non-existent fields
                if (fieldToken == null) {
                    System.debug(LoggingLevel.WARN, 'Skipping non-existent field: ' + rawKey);
                    continue;
                }

                Schema.DescribeFieldResult dfr = fieldToken.getDescribe();

                // Skip non-editable fields (system fields, formula, etc.)
                if (!dfr.isCreateable() && !dfr.isUpdateable()) {
                    System.debug(LoggingLevel.WARN, 'Skipping non-editable field: ' + rawKey);
                    continue;
                }

                try {
                    // Use canonical field name from describe so casing is always correct
                    record.put(dfr.getName(), payload.get(rawKey));
                } catch (SObjectException e) {
                    System.debug(LoggingLevel.WARN,
                        'Type error setting ' + rawKey + ': ' + e.getMessage());
                }
            }

            records.add(record);
        }

        return records;
    }

    /**
     * Queries which external-ID values already exist using queryWithBinds + USER_MODE,
     * so FLS and sharing rules are enforced at query time.
     * Logs how many records will be inserted vs updated.
     */
    private static void logPreUpsertSummary(
        String objectName,
        String externalIdField,
        List<Map<String, Object>> payloads
    ) {
        Set<String> extIdValues = new Set<String>();
        for (Map<String, Object> payload : payloads) {
            Object val = payload.get(externalIdField);
            if (val == null) val = payload.get(externalIdField.toLowerCase());
            if (val != null) extIdValues.add(String.valueOf(val));
        }
        if (extIdValues.isEmpty()) return;

        String safeField  = String.escapeSingleQuotes(externalIdField);
        String safeObject = String.escapeSingleQuotes(objectName);
        String query = 'SELECT ' + safeField
                     + ' FROM '  + safeObject
                     + ' WHERE ' + safeField + ' IN :extIdValues';

        List<SObject> existing = Database.queryWithBinds(
            query,
            new Map<String, Object>{ 'extIdValues' => extIdValues },
            AccessLevel.USER_MODE
        );

        Integer toUpdate = existing.size();
        Integer toInsert = payloads.size() - toUpdate;
        System.debug(LoggingLevel.INFO,
            '[GenericUpsertService] ' + objectName
            + ' — to insert: ' + toInsert
            + ', to update: ' + toUpdate);
    }

    private static void logFailures(
        Database.UpsertResult[] results,
        List<SObject> records
    ) {
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                List<String> msgs = new List<String>();
                for (Database.Error err : results[i].getErrors()) {
                    msgs.add(err.getStatusCode() + ': ' + err.getMessage());
                }
                System.debug(LoggingLevel.ERROR,
                    '[GenericUpsertService] Upsert failed for record[' + i + '] '
                    + records[i].getSObjectType() + ' — '
                    + String.join(msgs, ' | '));
            }
        }
    }
}
