@isTest
public class GenericUpsertServiceTest {

    // ── Test 1: campo inexistente en el payload → se ignora sin excepción ────
    @isTest
    static void testNonExistentFieldIsIgnored() {
        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Name'               => 'Acme Corp',
                'BogusFieldXYZ__xyz' => 'should be silently skipped'
            }
        };

        Test.startTest();
        GenericUpsertService.upsertRecords('Account', null, payloads);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = 'Acme Corp'],
            'Account debe crearse; el campo inexistente no debe lanzar excepción'
        );
    }

    // ── Test 2: campo no editable (CreatedDate) → se ignora sin excepción ────
    @isTest
    static void testNonEditableFieldIsIgnored() {
        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Name'        => 'Editable Test Corp',
                'CreatedDate' => Date.today()   // campo de sistema, isCreateable=false, isUpdateable=false
            }
        };

        Test.startTest();
        GenericUpsertService.upsertRecords('Account', null, payloads);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = 'Editable Test Corp'],
            'Account debe crearse; el campo no editable no debe lanzar excepción'
        );
    }

    // ── Test 3: error parcial → fallo loggeado, el otro registro se commitea ─
    @isTest
    static void testPartialFailureIsLoggedWithoutCancellingOthers() {
        String validName = 'Valid Partial Account';

        // El segundo registro tiene Name de 256 chars (límite es 255) → STRING_TOO_LONG
        List<Map<String, Object>> payloads = new List<Map<String, Object>>{
            new Map<String, Object>{ 'Name' => validName },
            new Map<String, Object>{ 'Name' => 'x'.repeat(256) }
        };

        Test.startTest();
        // No debe lanzar excepción: allOrNone = false absorbe el fallo parcial
        GenericUpsertService.upsertRecords('Account', null, payloads);
        Test.stopTest();

        Assert.areEqual(
            1,
            [SELECT COUNT() FROM Account WHERE Name = :validName],
            'El registro válido debe commitearse aunque su hermano haya fallado'
        );
    }

    // ── Test 4: objeto inexistente → UpsertException ──────────────────────────
    @isTest
    static void testInvalidObjectThrowsUpsertException() {
        Boolean threw = false;
        try {
            Test.startTest();
            GenericUpsertService.upsertRecords(
                'FakeObject__xyz',
                null,
                new List<Map<String, Object>>{ new Map<String, Object>{ 'Name' => 'x' } }
            );
            Test.stopTest();
        } catch (GenericUpsertService.UpsertException e) {
            threw = true;
        }

        Assert.isTrue(threw, 'Debe lanzar UpsertException para un objeto inexistente');
    }

    // ── Test 5: externalIdField inexistente → UpsertException ────────────────
    @isTest
    static void testInvalidExternalIdFieldThrowsUpsertException() {
        Boolean threw = false;
        try {
            Test.startTest();
            GenericUpsertService.upsertRecords(
                'Account',
                'NonExistentExtId__xyz',
                new List<Map<String, Object>>{ new Map<String, Object>{ 'Name' => 'x' } }
            );
            Test.stopTest();
        } catch (GenericUpsertService.UpsertException e) {
            threw = true;
        }

        Assert.isTrue(threw, 'Debe lanzar UpsertException para un external ID field inexistente');
    }
}
