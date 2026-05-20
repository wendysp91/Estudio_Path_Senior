public with sharing class EndpointVerifyContactMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);
        String requestBody = req.getBody();
        List<String> emails = (List<String>) JSON.deserialize(requestBody, List<String>.class);

        Map<String, Object> responseMap = new Map<String, Object>();
        List<Map<String, String>> emailList = new List<Map<String, String>>();

        if (emails != null && !emails.isEmpty()) {
            for (String email : emails) {
                Map<String, String> emailStatus = new Map<String, String>();
                emailStatus.put('email', email);
                // Ejemplo: asigna 'verified' al primero, 'not verified' al segundo, el resto 'not verified'
                if (email == 'mengana@emailin.com') {
                    emailStatus.put('status', 'verified');
                } else if (email == 'fulana@emailin.com') {
                    emailStatus.put('status', 'not verified');
                } else {
                    emailStatus.put('status', 'not verified');
                }
                emailList.add(emailStatus);
            }
        }
        responseMap.put('emailList', emailList);
        res.setBody(JSON.serialize(responseMap));
        return res;
    }
}