@isTest
public class BatchVerifyContactTest {
    @testSetup
    static void setupData() {
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName='Mengana', LastName='Test', Email='mengana@emailin.com', Email_Verified__c=false),
            new Contact(FirstName='Fulana', LastName='Test', Email='fulana@emailin.com', Email_Verified__c=false),
            new Contact(FirstName='Otro', LastName='Test', Email='otro@emailin.com', Email_Verified__c=false)
        };
        insert contacts;
    }

    @isTest
    static void testBatchVerifyContact() {
        // Set mock para callouts
        Test.setMock(HttpCalloutMock.class, new EndpointVerifyContactMock());

        // Ejecutar el batch
        Test.startTest();
        BatchVerifyContact batch = new BatchVerifyContact();
        Database.executeBatch(batch, 2);
        Test.stopTest();

        // Verificar que los contactos correctos fueron actualizados
        List<Contact> updatedContacts = [SELECT Email, Email_Verified__c FROM Contact WHERE Email IN ('mengana@emailin.com', 'fulana@emailin.com', 'otro@emailin.com')];
        Map<String, Boolean> emailToVerified = new Map<String, Boolean>();
        for(Contact c : updatedContacts) {
            emailToVerified.put(c.Email, c.Email_Verified__c);
        }
        System.assertEquals(true, emailToVerified.get('mengana@emailin.com'), 'Mengana debe estar verificado');
        System.assertEquals(false, emailToVerified.get('fulana@emailin.com'), 'Fulana no debe estar verificado');
        System.assertEquals(false, emailToVerified.get('otro@emailin.com'), 'Otro no debe estar verificado');
    }
}