@isTest
private class ResubmissionLauncherBatch_Test {

    @isTest
    static void testLauncherBatchExecution() {
        // 1. Setup
        Account acc = new Account(Name = 'Test Launcher Account');
        insert acc;

        String className = 'AccountCalloutBatchExample';
        String paramsJson = '{"endpoint":"test.com"}';
        String paramsHash = 'XXXXXXXXXX';

        insert new Batch_Resubmission_Item__c(
            Target_Record_Id__c = acc.Id,
            Batch_Class_Name__c = className,
            Constructor_Params_JSON__c = paramsJson,
            Params_Hash__c = paramsHash,
            Status__c = 'New'
        );

        // 2. Execute
        Test.startTest();
        ResubmissionLauncherBatch launcher = new ResubmissionLauncherBatch(className, paramsHash);
        Database.executeBatch(launcher);
        Test.stopTest();

        // 3. Verify
        // The launcher must update the item's status to 'Completed'
        Batch_Resubmission_Item__c updatedItem = [
            SELECT Status__c, Batch_Job_Id__c 
            FROM Batch_Resubmission_Item__c WHERE Target_Record_Id__c = :acc.Id
        ];
        System.assertEquals('Completed', updatedItem.Status__c, 'Lo stato doveva essere aggiornato a Completed.');
        System.assertNotEquals(null, updatedItem.Batch_Job_Id__c, 'Il Batch Job ID doveva essere popolato.');
        
        // Verify that the target batch (AccountCalloutBatch) was started
        List<AsyncApexJob> jobs = [
            SELECT ApexClass.Name 
            FROM AsyncApexJob 
            WHERE JobType = 'BatchApex' AND ApexClass.Name = 'AccountCalloutBatchExample'
        ];
        System.assertEquals(1, jobs.size(), 'Il batch target AccountCalloutBatch doveva essere avviato.');
    }
}