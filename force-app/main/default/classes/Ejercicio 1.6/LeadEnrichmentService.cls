public class LeadEnrichmentService {
    private ExternalDataAPI api;

    public LeadEnrichmentService(ExternalDataAPI api) {
        this.api = api;
    }

    public void enrichLeads(List<Lead> leads) {
        List<Lead> toUpdate = new List<Lead>();

        for (Lead lead : leads) {
            if (String.isBlank(lead.Email)) continue;

            try {
                Map<String, Object> data = api.lookupByEmail(lead.Email);
                if (data == null) continue;

                lead.Company     = (String) data.get('company');
                lead.Industry    = (String) data.get('industry');
                lead.Enriched__c = true;
                toUpdate.add(lead);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'API error for lead ' + lead.Id + ': ' + e.getMessage());
            }
        }

        if (!toUpdate.isEmpty()) {
            List<Database.SaveResult> results = Database.update(toUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug(LoggingLevel.ERROR,
                        'DML error for lead ' + toUpdate[i].Id + ': ' +
                        results[i].getErrors()[0].getMessage());
                }
            }
        }
    }
}
