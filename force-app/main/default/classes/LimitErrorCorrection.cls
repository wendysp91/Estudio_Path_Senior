public with sharing class LimitErrorCorrection {
    public static void processOrders(List<Order__c> orders) {
        List<Order> ordersToUpdate = new List<Order>();
        Map<Id, Account> accountMap = [Select Id, Name From Account Where Id IN :orders.Account__c];
        Map<Id, List<Product2>> productMap = [Select Id, Price__c From Product__c Where Id IN (Select Product__c From Order_Product__c Where Order__c IN :orders)];

        for (Order__c order : orders) {
            accountMap.put(order.Account__c, null);
            productMap.put(order.Id, new List<Product2>());
        }

            for (Order__c order : orders) {
                List<String> summaryParts = new List<String>();
            
                for (Product__c p : productMap.get(order.Id)) {
                    summaryParts.add(p.Id + ', ' + String.valueOf(p.Price__c));
                }
            
            order.Summary__c = String.join(summaryParts, '|');
            order.Account_Name__c = accountMap.get(order.Account__c).Name;
            ordersToUpdate.add(order);
        }
        
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalSystem/orders');
        req.setMethod('POST');
        req.setBody(JSON.serialize(ordersToUpdate));
        h.send(req);

        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
}