public class ResubmissionHelper {
    /**
     * @description Crea in blocco i record Batch_Resubmission_Item__c.
     * @param recordIds Lista degli ID dei record da risottomettere.
     * @param batchClassName Nome della classe batch target.
     * @param jsonParams Parametri di configurazione in formato JSON.
     * @param batchSize Dimensione dello scope per il batch.
     */
    public static void createResubmissionItems(List<Id> recordIds, String batchClassName, String jsonParams, Integer batchSize) {
        String paramsHash = '';
        if (String.isNotBlank(jsonParams)) {
            Blob hashBlob = Crypto.generateDigest('SHA1', Blob.valueOf(jsonParams));
            paramsHash = EncodingUtil.convertToHex(hashBlob);
        }

        List<Batch_Resubmission_Item__c> itemsToInsert = new List<Batch_Resubmission_Item__c>();
        for (Id recordId : recordIds) {
            itemsToInsert.add(new Batch_Resubmission_Item__c(
                Target_Record_Id__c = recordId,
                Batch_Class_Name__c = batchClassName,
                Constructor_Params_JSON__c = jsonParams,
                Params_Hash__c = paramsHash,
                Batch_Size__c = batchSize
            ));
        }

        if (!itemsToInsert.isEmpty()) {
            Database.upsert(itemsToInsert, Batch_Resubmission_Item__c.Target_Record_Id__c.getDescribe().getSObjectField(), false);
        }
    }
}