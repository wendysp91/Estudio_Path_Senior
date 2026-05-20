public with sharing class FinalizerErrorHandling implements Finalizer {

    public void execute(FinalizerContext ctx) {
        if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
            Exception e = ctx.getException();
            System.debug(LoggingLevel.ERROR, 'Fallo catastrófico en Queueable: ' + e.getMessage());

            // PE para que el log sobreviva aunque la transacción del Queueable falle
            EventBus.publish(new Log_Error_Event__e(
                Error_Message__c = 'Fallo catastrófico: ' + e.getMessage()
            ));

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] {'admin@example.com'});
            mail.setSubject('Fallo catastrófico en procesamiento de Contacts');
            mail.setPlainTextBody('Error irrecuperable en el Queueable: ' + e.getMessage());
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }
    }
}
