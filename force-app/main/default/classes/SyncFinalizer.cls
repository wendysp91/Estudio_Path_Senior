public with sharing class SyncFinalizer implements Finalizer {
    public void execute(FinalizerContext ctx) {
        System.debug('Finalizer executed.');
        if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
            Exception e = ctx.getException();
            System.debug('Unhandled exception occurred: ' + e.getMessage());
            // loggear el error, notificar, re-encolar si aplica
            Integration_Error__c errorRecord = new Integration_Error__c(
                Name = 'BatchVerifyContact Failure',
                Error_Message__c = e.getMessage(),
                Stack_Trace__c = e.getStackTraceString(),
                Job_Type__c = 'BatchVerifyContact'
            );
            insert errorRecord;
        }
    }
    
}