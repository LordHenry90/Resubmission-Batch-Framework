/**
 * @description Questo batch generico funge da "launcher". Raccoglie tutti gli ID per un
 * dato gruppo di lavoro (stessa classe e stessi parametri) e, una volta terminato,
 * avvia il batch target finale con tutti i dati necessari.
 */
public class ResubmissionLauncherBatch implements Database.Batchable<SObject>, Database.Stateful {

    private final String targetBatchClassName;
    private final String paramsHash;
    private List<Id> recordIdsToProcess = new List<Id>();
    private String launcherJobId;

    /**
     * @description Costruttore che riceve il gruppo di lavoro da processare.
     */
    public ResubmissionLauncherBatch(String targetBatchClassName, String paramsHash) {
        this.targetBatchClassName = targetBatchClassName;
        this.paramsHash = paramsHash;
    }

    /**
     * @description Metodo start: Esegue una query su tutti gli item che corrispondono
     * al gruppo di lavoro identificato dallo scheduler.
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        this.launcherJobId = bc.getJobId();
        
        // Aggiorna lo stato degli item a 'In Progress' per evitare che vengano
        // riprocessati dalla schedulazione successiva.
        List<Batch_Resubmission_Item__c> itemsToUpdate = [
            SELECT Id FROM Batch_Resubmission_Item__c
            WHERE Batch_Class_Name__c = :this.targetBatchClassName
            AND Params_Hash__c = :this.paramsHash
            AND Status__c = 'New'
        ];
        
        for(Batch_Resubmission_Item__c item : itemsToUpdate){
            item.Status__c = 'In Progress';
            item.Batch_Job_Id__c = this.launcherJobId;
        }
        update itemsToUpdate;

        return Database.getQueryLocator([
            SELECT Target_Record_Id__c
            FROM Batch_Resubmission_Item__c
            WHERE Id IN :itemsToUpdate
        ]);
    }

    /**
     * @description Metodo execute: Raccoglie tutti gli ID dei record target.
     */
    public void execute(Database.BatchableContext bc, List<Batch_Resubmission_Item__c> scope) {
        for (Batch_Resubmission_Item__c item : scope) {
            recordIdsToProcess.add(item.Target_Record_Id__c);
        }
    }

    /**
     * @description Metodo finish: Il cuore del framework. Istanzia e avvia il batch target.
     */
    public void finish(Database.BatchableContext bc) {
        if (recordIdsToProcess.isEmpty()) {
            System.debug('Nessun record ID raccolto per ' + targetBatchClassName);
            return;
        }

        Type targetType = Type.forName(targetBatchClassName);
        if (targetType == null) {
            System.debug(LoggingLevel.ERROR, 'Classe batch non trovata: ' + targetBatchClassName);
            return;
        }

        Batch_Resubmission_Item__c sampleItem = [
            SELECT Constructor_Params_JSON__c, Batch_Size__c
            FROM Batch_Resubmission_Item__c
            WHERE Batch_Class_Name__c = :this.targetBatchClassName
            AND Params_Hash__c = :this.paramsHash
            AND Batch_Job_Id__c = :this.launcherJobId
            LIMIT 1
        ];
        
        String paramsJSON = sampleItem.Constructor_Params_JSON__c;
        Map<String, Object> paramsMap = new Map<String, Object>();

        if (String.isNotBlank(paramsJSON)) {
            paramsMap = (Map<String, Object>) JSON.deserializeUntyped(paramsJSON);
        }
        
        // Aggiunge la lista di ID e l'ID del job del launcher ai parametri
        paramsMap.put('recordIdsToProcess', recordIdsToProcess);
        paramsMap.put('frameworkJobId', this.launcherJobId);
        String finalJson = JSON.serialize(paramsMap);

        try {
            Object targetBatchInstance = JSON.deserialize(finalJson, targetType);

            if (targetBatchInstance instanceof Database.Batchable<SObject>) {
                Database.Batchable<SObject> batchToRun = (Database.Batchable<SObject>) targetBatchInstance;
                Integer batchSize = (sampleItem.Batch_Size__c != null) ? Integer.valueOf(sampleItem.Batch_Size__c) : null;

                if (batchSize != null && batchSize > 0) {
                    Database.executeBatch(batchToRun, batchSize);
                    System.debug('Avviato batch ' + targetBatchClassName + ' con batch size: ' + batchSize);
                } else {
                    Database.executeBatch(batchToRun);
                    System.debug('Avviato batch ' + targetBatchClassName + ' con batch size di default.');
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'La classe ' + targetBatchClassName + ' non è un batch.');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Errore durante l\'avvio del batch ' + targetBatchClassName + ': ' + e.getMessage());
        }
    }
}