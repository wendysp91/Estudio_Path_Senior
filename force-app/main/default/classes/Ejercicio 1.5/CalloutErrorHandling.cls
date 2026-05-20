public with sharing class CalloutErrorHandling {

    public List<Contact> makeCalloutWithErrorHandling(List<Contact> contacts) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:ExternalService/verify');
        request.setMethod('GET');
        request.setHeader('Content-Type', 'application/json');
        request.setBody(JSON.serialize(contacts));

        try {
            HttpResponse response = http.send(request);

            if (response.getStatusCode() == 200) {
                return (List<Contact>) JSON.deserialize(response.getBody(), List<Contact>.class);
            }

            if (response.getStatusCode() == 401) {
                // Publicar PE antes de lanzar: el log sobrevive el rollback del chunk
                EventBus.publish(new Log_Error_Event__e(
                    Error_Message__c = '401 Unauthorized: ' + response.getBody()
                ));
                throw new AuthenticationException('401 Unauthorized: ' + response.getBody());
            }

            return new List<Contact>();

        } catch (AuthenticationException ae) {
            throw ae; // Propagate to execute() → cancels the chunk

        } catch (System.CalloutException ce) {
            // Timeout o fallo de red → loggear con PE y continuar (no cancelar chunk)
            EventBus.publish(new Log_Error_Event__e(
                Error_Message__c = 'Callout error: ' + ce.getMessage()
            ));
            return new List<Contact>();

        } catch (Exception e) {
            // Error inesperado → loggear con PE y encolar Queueable de recuperación
            EventBus.publish(new Log_Error_Event__e(
                Error_Message__c = 'Error inesperado en callout: ' + e.getMessage()
            ));
            System.enqueueJob(new QueueCalloutErrorHandling(contacts));
            return new List<Contact>();
        }
    }

    public class AuthenticationException extends Exception {}
}
