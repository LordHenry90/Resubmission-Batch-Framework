@isTest
private class ResubmissionScheduler_Test {

    @isTest
    static void testSchedulerExecution() {
        // 1. Setup: Create a resubmission item to be found by the scheduler
        ResubmissionHelper.createResubmissionItems(
            new List<Id>{'001000000000000AAA'}, 
            'AccountCalloutBatch', '', 200
        );

        // 2. Execute
        Test.startTest();
        String cron = '0 0 1 * * ?';
        String jobId = System.schedule('Test Resubmission Scheduler', cron, new ResubmissionScheduler());
        Test.stopTest();

        // 3. Verify
        // Test.stopTest() executes the scheduled job, which in turn starts the launcher batch.
        // We verify that a batch job has been enqueued.
        List<AsyncApexJob> jobs = [SELECT Id FROM AsyncApexJob WHERE JobType = 'BatchApex'];
        System.assert(!jobs.isEmpty(), 'Lo scheduler avrebbe dovuto avviare un batch job.');
    }
}