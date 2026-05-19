public with sharing class QueueVerifyContact implements Queueable {
    public List<Contact> contacts;

    public QueueVerifyContact(List<Contact> contacts) {
        this.contacts = contacts;
    }

    public void execute(QueueableContext context) {
        // Publicar Platform Event con el resumen
        VerificationCompleted__e event = new VerificationCompleted__e();
        event.TotalContacts__c = contacts.size();
        event.Message__c = 'Se han procesado ' + contacts.size() + ' contactos.';
        EventBus.publish(event);

        // Enviar email resumen de resultados
        System.debug(LoggingLevel.DEBUG, 'Queueable Job executed for ' + contacts.size() + ' contacts.');
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { 'admin@example.com' });
        email.setSubject('Resumen de Verificación de Contactos');
        email.setPlainTextBody('Se han procesado ' + contacts.size() + ' contactos.');
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
    }
}