trigger TriggerOnClient on Client__c (after insert, after update) {
    new RegionalSharingService().manageRegionalSharing(Trigger.new, Trigger.oldMap);
}
