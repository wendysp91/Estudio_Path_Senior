public with sharing class ServiceVerifyContact {
    public Map<String, String> makeCallout(List<String> email){
        List<Contact> verifiedContacts = new List<Contact>();
        Map<String, String> result = new Map<String, String>();
        try {
            // Prepare the HTTP request
            RestRequest req = new RestRequest();
            req.requestUri = 'https://api.emailverification.com/verify?email=';
            req.httpMethod = 'GET';
            req.addHeader('Authorization', 'Bearer your_api_key_here');
            req.requestBody = JSON.serialize(email);
            req.send();
            RestResponse res = req.getResponse();
            if(res.getStatusCode() == 200){
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Map<String, String>> emailList = (List<Map<String, String>>) responseMap.get('emailList');
                for(Map<String, String> emailStatus : emailList){
                    String emailAddr = emailStatus.get('email');
                    String status = emailStatus.get('status');
                    result.put(emailAddr, status);
                }
            } else {
                System.debug('Email verification failed for: ' + email);
            }
        } catch (Exception e) {
            System.debug('Error during email verification callout: ' + e.getMessage());
            System.attachFinalizer(new SyncFinalizer());
        }
        return result;
    }
}