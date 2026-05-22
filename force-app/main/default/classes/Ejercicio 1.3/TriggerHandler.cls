public virtual class TriggerHandler {

    @TestVisible
    private static Set<String> bypassed = new Set<String>();

    private String handlerName;

    public TriggerHandler() {
        this.handlerName = getHandlerName();
    }

    public void run() {
        if (!Trigger.isExecuting) return;
        if (isBypassed(handlerName)) return;

        switch on Trigger.operationType {
            when BEFORE_INSERT  { beforeInsert(); }
            when BEFORE_UPDATE  { beforeUpdate(); }
            when BEFORE_DELETE  { beforeDelete(); }
            when AFTER_INSERT   { afterInsert(); }
            when AFTER_UPDATE   { afterUpdate(); }
            when AFTER_DELETE   { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    // --- Bypass API ---

    public static void bypass(String handlerName) {
        bypassed.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassed.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassed.contains(handlerName);
    }

    public static void clearAllBypasses() {
        bypassed.clear();
    }

    // --- Hooks sobreescribibles ---

    protected virtual void beforeInsert()  {}
    protected virtual void beforeUpdate()  {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterInsert()   {}
    protected virtual void afterUpdate()   {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    // --- Helpers ---

    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }
}
