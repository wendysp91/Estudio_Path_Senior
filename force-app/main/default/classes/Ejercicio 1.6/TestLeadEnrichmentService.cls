@isTest
public with sharing class TestLeadEnrichmentService {

    // ── Mocks ────────────────────────────────────────────────────────────────

    class MockAPI implements ExternalDataAPI {
        public Map<String, Object> lookupByEmail(String email) {
            return new Map<String, Object>{
                'company'  => 'Acme Corp',
                'industry' => 'Technology'
            };
        }
    }

    class NullAPI implements ExternalDataAPI {
        public Map<String, Object> lookupByEmail(String email) {
            return null;
        }
    }

    // Cuenta llamadas para verificar que no se llama con email vacío
    class CountingAPI implements ExternalDataAPI {
        public Integer callCount = 0;
        public Map<String, Object> lookupByEmail(String email) {
            callCount++;
            return new Map<String, Object>{
                'company'  => 'Acme Corp',
                'industry' => 'Technology'
            };
        }
    }

    // Lanza excepción solo para el email indicado; los demás retornan datos
    class SelectiveFailingAPI implements ExternalDataAPI {
        private String failEmail;
        public SelectiveFailingAPI(String emailToFail) { this.failEmail = emailToFail; }
        public Map<String, Object> lookupByEmail(String email) {
            if (email == failEmail) throw new CalloutException('Simulated API error');
            return new Map<String, Object>{
                'company'  => 'Acme Corp',
                'industry' => 'Technology'
            };
        }
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    @testSetup
    static void setup() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 5; i++) {
            leads.add(new Lead(
                FirstName = 'Test',
                LastName  = 'Lead ' + i,
                Email     = 'test' + i + '@example.com'
            ));
        }
        leads.add(new Lead(FirstName = 'No', LastName = 'Email'));
        insert leads;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    @isTest
    static void testEnrichLeads_Success() {
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email != null];
        LeadEnrichmentService service = new LeadEnrichmentService(new MockAPI());

        Test.startTest();
        service.enrichLeads(leads);
        Test.stopTest();

        for (Lead l : [SELECT Company, Industry, Enriched__c FROM Lead WHERE Email != null]) {
            System.assertEquals('Acme Corp',  l.Company,     'Company incorrecto');
            System.assertEquals('Technology', l.Industry,    'Industry incorrecto');
            System.assertEquals(true,         l.Enriched__c, 'Enriched__c debe ser true');
        }
    }

    @isTest
    static void testEnrichLeads_LeadWithoutEmail() {
        // Setup: 5 leads con email + 1 sin email
        List<Lead> leads = [SELECT Id, Email FROM Lead];
        CountingAPI mock = new CountingAPI();
        LeadEnrichmentService service = new LeadEnrichmentService(mock);

        Test.startTest();
        service.enrichLeads(leads);
        Test.stopTest();

        // La API solo debe llamarse para los leads que tienen email
        System.assertEquals(5, mock.callCount, 'lookupByEmail no debe llamarse para leads sin email');

        Lead noEmail = [SELECT Company, Industry, Enriched__c FROM Lead WHERE Email = null LIMIT 1];
        System.assertEquals(null, noEmail.Company,     'Company debe seguir null');
        System.assertEquals(null, noEmail.Industry,    'Industry debe seguir null');
        System.assertEquals(null, noEmail.Enriched__c, 'Enriched__c debe seguir null');
    }

    @isTest
    static void testEnrichLeads_ApiReturnsNull() {
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email != null];
        LeadEnrichmentService service = new LeadEnrichmentService(new NullAPI());

        Test.startTest();
        service.enrichLeads(leads);
        Test.stopTest();

        for (Lead l : [SELECT Company, Industry, Enriched__c FROM Lead WHERE Email != null]) {
            System.assertEquals(null, l.Company,     'Company no debe modificarse');
            System.assertEquals(null, l.Industry,    'Industry no debe modificarse');
            System.assertEquals(null, l.Enriched__c, 'Enriched__c no debe modificarse');
        }
    }

    @isTest
    static void testEnrichLeads_ApiThrowsException() {
        // La API falla solo para test0; el resto debe seguir procesándose
        String failEmail = 'test0@example.com';
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email != null];
        LeadEnrichmentService service = new LeadEnrichmentService(new SelectiveFailingAPI(failEmail));

        Test.startTest();
        Boolean threw = false;
        try {
            service.enrichLeads(leads);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'El servicio no debe propagar excepciones de la API');

        Lead failedLead = [SELECT Enriched__c FROM Lead WHERE Email = :failEmail];
        System.assertEquals(null, failedLead.Enriched__c, 'El lead con API fallida no debe enriquecerse');

        for (Lead l : [SELECT Enriched__c FROM Lead WHERE Email != :failEmail AND Email != null]) {
            System.assertEquals(true, l.Enriched__c, 'Los demás leads deben enriquecerse');
        }
    }

    @isTest
    static void testEnrichLeads_DmlPartialFailure() {
        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email != null];

        // Eliminar el primer lead en DB para que su ID ya no exista al hacer update
        delete leads[0];
        // leads[0] permanece en memoria con el ID eliminado → Database.update fallará para él

        LeadEnrichmentService service = new LeadEnrichmentService(new MockAPI());

        Test.startTest();
        Boolean threw = false;
        try {
            service.enrichLeads(leads);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'El servicio no debe propagar errores DML parciales');

        // Los 4 leads válidos (aún en DB) deben haberse enriquecido
        for (Lead l : [SELECT Company, Enriched__c FROM Lead WHERE Email != null]) {
            System.assertEquals('Acme Corp', l.Company);
            System.assertEquals(true, l.Enriched__c);
        }
    }

    @isTest
    static void testEnrichLeads_Bulk200() {
        List<Lead> bulkLeads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            bulkLeads.add(new Lead(
                FirstName = 'Bulk',
                LastName  = 'Lead ' + i,
                Email     = 'bulk' + i + '@example.com'
            ));
        }
        insert bulkLeads;

        List<Lead> leads = [SELECT Id, Email FROM Lead WHERE Email LIKE 'bulk%@example.com'];
        System.assertEquals(200, leads.size(), 'Deben existir 200 leads bulk');

        LeadEnrichmentService service = new LeadEnrichmentService(new MockAPI());

        Test.startTest();
        service.enrichLeads(leads);
        Test.stopTest();

        for (Lead l : [SELECT Company, Industry, Enriched__c FROM Lead WHERE Email LIKE 'bulk%@example.com']) {
            System.assertEquals('Acme Corp',  l.Company);
            System.assertEquals('Technology', l.Industry);
            System.assertEquals(true,         l.Enriched__c);
        }
    }

    @isTest
    static void testEnrichedTrueMeansCompanyChanged() {
        List<Lead> before = [SELECT Id, Email, Company FROM Lead WHERE Email != null];
        for (Lead l : before) {
            System.assertEquals(null, l.Company, 'Company debe ser null antes del enriquecimiento');
        }

        LeadEnrichmentService service = new LeadEnrichmentService(new MockAPI());

        Test.startTest();
        service.enrichLeads(before);
        Test.stopTest();

        for (Lead l : [SELECT Company, Enriched__c FROM Lead WHERE Enriched__c = true]) {
            System.assertNotEquals(null,       l.Company, 'Company debe haber cambiado');
            System.assertEquals('Acme Corp',   l.Company, 'Company debe ser Acme Corp');
        }
    }
}
