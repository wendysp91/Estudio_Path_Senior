public with sharing class ServiceVerifyContact {
    public Map<String, String> makeCallout(List<String> email){
        Map<String, String> result = new Map<String, String>();
        try {
            // Prepare the HTTP request
            HttpRequest req = new HttpRequest();
            //req.setEndpoint('https://api.emailverification.com/verify');
            req.setEndpoint('callout:EmailVerificationAPI/verify');
            req.setMethod('GET');
            //req.setHeader('Authorization', 'Bearer your_api_key_here');
            req.setBody(JSON.serialize(email));
            Http http = new Http();
            HttpResponse res = http.send(req);
            if(res.getStatusCode() == 200){
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Map<String, String>> emailList = (List<Map<String, String>>) responseMap.get('emailList');
                for(Map<String, String> emailStatus : emailList){
                    String emailAddr = emailStatus.get('email');
                    String status = emailStatus.get('status');
                    result.put(emailAddr, status);
                }
            } else {
                System.debug(LoggingLevel.WARN, 'Email verification failed for: ' + email);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error during email verification callout: ' + e.getMessage());
            //System.attachFinalizer(new SyncFinalizer());
            Integration_Error__c errorRecord = new Integration_Error__c(
                Name = 'BatchVerifyContact Failure',
                Error_Message__c = e.getMessage(),
                Stack_Trace__c = e.getStackTraceString(),
                Job_Type__c = 'BatchVerifyContact'
            );
            insert errorRecord;
        }
        return result;
    }
}