public with sharing class SchedulerVerifyContact implements Schedulable {
    public void execute(SchedulableContext sc) {
        BatchVerifyContact batch = new BatchVerifyContact();
        Database.executeBatch(batch, 50);
    }
}

// Para programar el scheduler, puedes usar el siguiente código en la consola de desarrollador:
// String cronExp = '0 0 23 ? * *'; // Ejecutar cada noche a las 11pm
// System.schedule('Scheduler Verify Contact', cronExp, new SchedulerVerifyContact());
