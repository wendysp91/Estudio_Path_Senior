public without sharing class RegionalSharingService {

    public void manageRegionalSharing(List<Client__c> clients, Map<Id, Client__c> oldMap) {
        Map<String, Id> regionToGroup = new Map<String, Id>();
        for (Group g : [SELECT Id, Name FROM Group WHERE Type = 'Regular']) {
            regionToGroup.put(g.Name, g.Id);
        }

        List<Client__Share> toInsert       = new List<Client__Share>();
        Map<Id, Id>         parentToOldGroup = new Map<Id, Id>(); // clientId → oldGroupId

        for (Client__c c : clients) {
            if (oldMap != null && oldMap.containsKey(c.Id)) {
                Client__c old = oldMap.get(c.Id);
                if (old.Region__c != c.Region__c && old.Region__c != null) {
                    Id oldGroupId = regionToGroup.get(old.Region__c);
                    if (oldGroupId != null) {
                        parentToOldGroup.put(c.Id, oldGroupId);
                    }
                }
            }

            Id newGroupId = regionToGroup.get(c.Region__c);
            if (newGroupId != null) {
                toInsert.add(new Client__Share(
                    ParentId      = c.Id,
                    UserOrGroupId = newGroupId,
                    AccessLevel   = 'Read',
                    RowCause      = Schema.Client__Share.RowCause.Regional_Access__c
                ));
            }
        }

        if (!parentToOldGroup.isEmpty()) {
            List<Client__Share> toDelete = new List<Client__Share>();
            for (Client__Share sh : [
                SELECT Id, ParentId, UserOrGroupId
                FROM   Client__Share
                WHERE  ParentId IN :parentToOldGroup.keySet()
                  AND  RowCause = :Schema.Client__Share.RowCause.Regional_Access__c
            ]) {
                if (sh.UserOrGroupId == parentToOldGroup.get(sh.ParentId)) {
                    toDelete.add(sh);
                }
            }
            if (!toDelete.isEmpty()) delete toDelete;
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }
}
