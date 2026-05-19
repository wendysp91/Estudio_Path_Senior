public class BatchVerifyContact implements Database.Batchable<SObject>, Database.Stateful {

    public integer totalRecordsProcessed = 0;

    public QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator('SELECT Id, Email FROM Contact WHERE Email_Verified__c = false');
    }

    public void execute(Database.BatchableContext BC, List<Contact> scope){
        List<Contact> contactsToUpdate = new List<Contact>();
        List<String> emailsToVerify = new List<String>();
        for(Contact con : scope){
            emailsToVerify.add(con.Email);
        }

        List<Contact> verifiedContacts = verifyEmail(emailsToVerify);
        if(!verifiedContacts.isEmpty()){
            for(Contact con : verifiedContacts){
                con.Email_Verified__c = true;
                contactsToUpdate.add(con);
            }
        }
        update contactsToUpdate;
        totalRecordsProcessed += scope.size();
    }
    
    public void finish(Database.BatchableContext BC){
        System.debug('Total Records Processed: ' + totalRecordsProcessed);
        System.enqueueJob(new QueueVerifyContact(contacts));
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