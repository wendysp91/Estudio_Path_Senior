public class BatchVerifyContact implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    public integer totalRecordsProcessed = 0;
    public List<Contact> processedContacts = new List<Contact>();

    public QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Email FROM Contact WHERE Email_Verified__c = false');
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope){
        List<Contact> contactsToUpdate = new List<Contact>();
        List<String> emailsToVerify = new List<String>();
        Map<String, Contact> emailToContact = new Map<String, Contact>();
        for (Contact con : scope) {
            emailToContact.put(con.Email, con);
            emailsToVerify.add(con.Email);
        }

        List<Contact> verifiedContacts = verifyEmail(emailsToVerify);
        for (Contact contactEmailAddr : verifiedContacts) {
            if (emailToContact.containsKey(contactEmailAddr.Email)) {
                Contact c = emailToContact.get(contactEmailAddr.Email);
                c.Email_Verified__c = true;
                contactsToUpdate.add(c);
            }
        }
        update contactsToUpdate;
        totalRecordsProcessed += scope.size();
        processedContacts.addAll(verifiedContacts);
    }
    
    public void finish(Database.BatchableContext BC){
        System.debug(LoggingLevel.DEBUG, 'Total Records Processed: ' + totalRecordsProcessed);
        System.enqueueJob(new QueueVerifyContact(processedContacts));
    }

    private List<Contact> verifyEmail(List<String> email){
        ServiceVerifyContact svc = new ServiceVerifyContact();
        Map<String, String> verificationResults = svc.makeCallout(email);
        List<Contact> verifiedContacts = new List<Contact>();
        for(String emailAddr : verificationResults.keySet()){
            if(verificationResults.get(emailAddr) == 'verified'){
                verifiedContacts.add(new Contact(Email = emailAddr));
            }
        }
        return verifiedContacts;
    }
}