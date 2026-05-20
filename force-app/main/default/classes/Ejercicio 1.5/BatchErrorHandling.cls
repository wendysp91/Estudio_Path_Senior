public with sharing class BatchErrorHandling implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    private Integer totalRecordsProcessed = 0;
    private Integer totalErrors = 0;
    private Integer totalExitosos = 0;

    public Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Email FROM Contact');
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope) {
        CalloutErrorHandling svc = new CalloutErrorHandling();
        // AuthenticationException no se atrapa aquí → se propaga y cancela el chunk
        List<Contact> contactsToUpdate = svc.makeCalloutWithErrorHandling(scope);

        // Registros del scope que no llegaron al DML (fallo en callout) = errores
        totalErrors += scope.size() - contactsToUpdate.size();

        List<Database.UpdateResult> updateResults = Database.update(contactsToUpdate, false);
        for (Database.UpdateResult result : updateResults) {
            if (result.isSuccess()) {
                totalExitosos++;
            } else {
                totalErrors++;
                // PE sobrevive el rollback del chunk
                EventBus.publish(new Log_Error_Event__e(
                    Record_Id__c = result.getId(),
                    Error_Message__c = result.getErrors()[0].getMessage()
                ));
            }
        }
        totalRecordsProcessed += scope.size();
    }

    public void finish(Database.BatchableContext BC) {
        System.debug(LoggingLevel.INFO, 'Total Procesados: ' + totalRecordsProcessed);
        System.debug(LoggingLevel.INFO, 'Total Exitosos: ' + totalExitosos);
        System.debug(LoggingLevel.INFO, 'Total Errores: ' + totalErrors);

        if (totalErrors > 100) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {'admin@example.com'});
            mail.setSubject('Errores en Batch de Verificación de Contactos');
            mail.setPlainTextBody(
                'Resumen del batch:\n' +
                'Procesados: ' + totalRecordsProcessed + '\n' +
                'Exitosos:   ' + totalExitosos + '\n' +
                'Errores:    ' + totalErrors
            );
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}
