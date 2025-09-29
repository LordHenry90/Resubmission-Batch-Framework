@isTest
private class ResubmissionHelper_Test {

    @isTest
    static void testCreateItems() {
        // 1. Setup
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        String className = 'AccountCalloutBatch';
        Map<String, Object> params = new Map<String, Object>{
            'endpoint' => 'test.endpoint.com',
            'timeout' => 120
        };
        Integer batchSize = 50;

        // 2. Execute
        Test.startTest();
        ResubmissionHelper.createResubmissionItems(new List<Id>{acc.Id}, className, JSON.serialize(params), batchSize);
        Test.stopTest();

        // 3. Verify
        List<Batch_Resubmission_Item__c> items = [
            SELECT Target_Record_Id__c, Batch_Class_Name__c, Constructor_Params_JSON__c, 
                   Params_Hash__c, Batch_Size__c, Status__c
            FROM Batch_Resubmission_Item__c
        ];
        
        System.assertEquals(1, items.size(), 'Un item di risottomissione doveva essere creato.');
        
        Batch_Resubmission_Item__c item = items[0];
        System.assertEquals(acc.Id, item.Target_Record_Id__c);
        System.assertEquals(className, item.Batch_Class_Name__c);
        System.assertEquals(JSON.serialize(params), item.Constructor_Params_JSON__c);
        System.assertNotEquals(null, item.Params_Hash__c, 'L\'hash dei parametri non deve essere nullo.');
        System.assertEquals(batchSize, item.Batch_Size__c);
        System.assertEquals('New', item.Status__c);
    }
}