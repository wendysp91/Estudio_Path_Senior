public with sharing class QueueCalloutErrorHandling implements Queueable {

    private List<Contact> contacts;

    public QueueCalloutErrorHandling(List<Contact> contacts) {
        this.contacts = contacts;
    }

    public void execute(QueueableContext context) {
        System.attachFinalizer(new FinalizerErrorHandling());
        // Lógica de recuperación: reintentar callout, notificar, etc.
    }
}
