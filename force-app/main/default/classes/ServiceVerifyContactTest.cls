@isTest
public class ServiceVerifyContactTest {
    @isTest
    static void testMakeCallout_Success() {
        // Prepara el mock de callout
        Test.setMock(HttpCalloutMock.class, new EndpointVerifyContactMock());

        // Emails de prueba
        List<String> emails = new List<String>{
            'mengana@emailin.com',
            'fulana@emailin.com'
        };

        // Ejecuta el método
        Test.startTest();
        ServiceVerifyContact svc = new ServiceVerifyContact();
        Map<String, String> result = svc.makeCallout(emails);
        Test.stopTest();

        // Verifica resultados
        System.assertEquals(2, result.size());
        System.assertEquals('verified', result.get('mengana@emailin.com'));
        System.assertEquals('not verified', result.get('fulana@emailin.com'));
    }

    @isTest
    static void testMakeCallout_Exception() {
        // No se setea mock para forzar excepción
        List<String> emails = new List<String>{'test@email.com'};

        Test.startTest();
        ServiceVerifyContact svc = new ServiceVerifyContact();
        Map<String, String> result = svc.makeCallout(emails);
        Test.stopTest();

        // Verifica que el resultado esté vacío y se haya insertado un error
        System.assertEquals(0, result.size());
        List<Integration_Error__c> errors = [SELECT Id FROM Integration_Error__c WHERE Name = 'BatchVerifyContact Failure'];
        System.assert(!errors.isEmpty(), 'Debe haberse insertado un registro de error');
    }
}