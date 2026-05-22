public with sharing class ClientController {
    @AuraEnabled(cacheable=true)
    public static List<Client__c> getClients() {
        return [SELECT Id, Name, Region__c FROM Client__c WITH USER_MODE];
    }
}
