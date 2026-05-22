// Requiere OWD de Client__c en "Private" y Share Reason "Regional_Access__c" desplegados
@isTest
public with sharing class TestSharing {

    @isTest
    static void usuarioNorteVeClienteNorteYNoSur() {
        Group norte = new Group(Name = 'Norte', Type = 'Regular');
        Group sur   = new Group(Name = 'Sur',   Type = 'Regular');
        insert new List<Group>{ norte, sur };

        User userNorte, userSur;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            userNorte = crearUsuario('uNorte1@test.example.com', 'uNort1', norte.Id);
            userSur   = crearUsuario('uSur1@test.example.com',   'uSur1',  sur.Id);
        }

        // El trigger dispara el sharing al insertar
        Test.startTest();
        Client__c clientNorte = new Client__c(Name = 'Cliente Norte', Region__c = 'Norte');
        Client__c clientSur   = new Client__c(Name = 'Cliente Sur',   Region__c = 'Sur');
        insert new List<Client__c>{ clientNorte, clientSur };
        Test.stopTest();

        System.runAs(userNorte) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(visibles.contains(clientNorte.Id), 'Norte debe ver cliente Norte');
            System.assert(!visibles.contains(clientSur.Id),  'Norte NO debe ver cliente Sur');
        }
        System.runAs(userSur) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(visibles.contains(clientSur.Id),    'Sur debe ver cliente Sur');
            System.assert(!visibles.contains(clientNorte.Id), 'Sur NO debe ver cliente Norte');
        }
    }

    @isTest
    static void alCambiarRegionElSharingSeReasigna() {
        Group norte = new Group(Name = 'Norte', Type = 'Regular');
        Group sur   = new Group(Name = 'Sur',   Type = 'Regular');
        insert new List<Group>{ norte, sur };

        User userNorte, userSur;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            userNorte = crearUsuario('uNorte2@test.example.com', 'uNort2', norte.Id);
            userSur   = crearUsuario('uSur2@test.example.com',   'uSur2',  sur.Id);
        }

        // Insert en Sur – trigger asigna sharing a grupo Sur
        Client__c cliente = new Client__c(Name = 'Cliente Movible', Region__c = 'Sur');
        insert cliente;

        // Estado inicial: Sur lo ve, Norte no
        System.runAs(userSur) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(visibles.contains(cliente.Id), 'Sur debe ver cliente antes del cambio');
        }
        System.runAs(userNorte) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(!visibles.contains(cliente.Id), 'Norte NO debe ver cliente antes del cambio');
        }

        // Cambiar región Sur → Norte – trigger reasigna el sharing
        Test.startTest();
        cliente.Region__c = 'Norte';
        update cliente;
        Test.stopTest();

        // Sur ya no lo ve, Norte sí
        System.runAs(userSur) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(!visibles.contains(cliente.Id), 'Sur NO debe ver cliente después del cambio');
        }
        System.runAs(userNorte) {
            Set<Id> visibles = new Map<Id, Client__c>([SELECT Id FROM Client__c]).keySet();
            System.assert(visibles.contains(cliente.Id), 'Norte debe ver cliente después del cambio');
        }
    }

    private static User crearUsuario(String email, String alias, Id groupId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            Username          = email,
            LastName          = 'Test',
            Email             = email,
            Alias             = alias,
            TimeZoneSidKey    = 'America/Los_Angeles',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            ProfileId         = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        insert new GroupMember(GroupId = groupId, UserOrGroupId = u.Id);
        return u;
    }
}
