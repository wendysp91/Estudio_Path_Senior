public class OpportunityTriggerHandler extends TriggerHandler {

    // Flag para que scripts de migración puedan saltar syncToERP sin deshabilitar el handler entero.
    // Uso: OpportunityTriggerHandler.skipSyncToERP = true;  → bulk insert → reset a false.
    @TestVisible
    public static Boolean skipSyncToERP = false;

    private List<Opportunity> newList;
    private Map<Id, Opportunity> oldMap;

    public OpportunityTriggerHandler() {
        this.newList = (List<Opportunity>) Trigger.new;
        this.oldMap  = (Map<Id, Opportunity>) Trigger.oldMap;
    }

    // ── before insert ────────────────────────────────────────────────────────
    protected override void beforeInsert() {
        setDefaults(newList);
    }

    // ── after insert ─────────────────────────────────────────────────────────
    protected override void afterInsert() {
        if (!skipSyncToERP) {
            OpportunityService.syncToERP(newList);
        }
    }

    // ── after update ─────────────────────────────────────────────────────────
    protected override void afterUpdate() {
        List<Opportunity> closedWon = filterNewlyClosedWon(newList, oldMap);
        if (!closedWon.isEmpty()) {
            notifyClosedWon(closedWon);
        }
    }

    // ── private helpers ──────────────────────────────────────────────────────

    private static void setDefaults(List<Opportunity> opps) {
        for (Opportunity opp : opps) {
            opp.StageName        = 'New';
            opp.Assigned_Date__c = Date.today();
        }
    }

    // Bulk-safe: recorre la lista una sola vez y devuelve sólo las que cambiaron.
    private static List<Opportunity> filterNewlyClosedWon(
        List<Opportunity> newOpps,
        Map<Id, Opportunity> oldMap
    ) {
        List<Opportunity> result = new List<Opportunity>();
        for (Opportunity opp : newOpps) {
            if (opp.StageName == 'Closed Won'
                && oldMap.get(opp.Id).StageName != 'Closed Won')
            {
                result.add(opp);
            }
        }
        return result;
    }

    private static void notifyClosedWon(List<Opportunity> opps) {
        // TODO: implementar notificación al equipo (email, chatter post, etc.)
    }
}
