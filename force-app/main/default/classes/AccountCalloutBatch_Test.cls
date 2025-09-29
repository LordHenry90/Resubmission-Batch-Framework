@isTest
private class AccountCalloutBatch_Test {

    @isTest
    static void testTargetBatchSuccessFlow() {
        // 1. Setup
        Account acc = new Account(Name = 'Test Callout Account');
        insert acc;
        
        // Simulate an item created by the framework, awaiting status update
        // We use a dummy Job ID
        String dummyFrameworkJobId = '707000000000000';
        insert new Batch_Resubmission_Item__c(
            Target_Record_Id__c = acc.Id,
            Batch_Class_Name__c = 'AccountCalloutBatch',
            Status__c = 'In Progress',
            Batch_Job_Id__c = dummyFrameworkJobId // This is the ID the batch will look for
        );
        
        // 2. Execute
        Test.startTest();
        AccountCalloutBatchExample targetBatch = new AccountCalloutBatchExample();
        // Simulate parameter injection by the framework
        targetBatch.recordIdsToProcess = new List<Id>{acc.Id};
        targetBatch.frameworkJobId = dummyFrameworkJobId; // Pass the dummy ID
        targetBatch.endpoint = 'test.endpoint.com';
        targetBatch.timeout = 120;
        
        Database.executeBatch(targetBatch);
        Test.stopTest();
        
        // 3. Verify
        // The batch's finish method should have updated the item to 'Completed'
        Batch_Resubmission_Item__c finalItem = [
            SELECT Status__c 
            FROM Batch_Resubmission_Item__c WHERE Target_Record_Id__c = :acc.Id
        ];
        System.assertEquals('Completed', finalItem.Status__c, 'Lo stato finale doveva essere Completed.');
    }
}