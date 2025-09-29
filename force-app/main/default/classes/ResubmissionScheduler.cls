/**
 * @description Classe schedulabile che avvia il framework di risottomissione.
 * Esegue una query per trovare gruppi di lavoro (stessa classe, stessi parametri)
 * e avvia un'istanza del ResubmissionLauncherBatch per ciascun gruppo.
 */
public class ResubmissionScheduler implements Schedulable {

    /**
     * @description Metodo execute, chiamato dallo scheduler di Salesforce.
     */
    public void execute(SchedulableContext sc) {
        // La query raggruppa tutti gli item in attesa per classe e per hash dei parametri.
        // Ogni risultato di questa query rappresenta un "gruppo di lavoro" da avviare.
        List<AggregateResult> workGroups = [
            SELECT
                Batch_Class_Name__c,
                Params_Hash__c
            FROM Batch_Resubmission_Item__c
            WHERE Status__c = 'New'
            GROUP BY Batch_Class_Name__c, Params_Hash__c
        ];

        if (workGroups.isEmpty()) {
            System.debug('ResubmissionScheduler: Nessun nuovo item da processare.');
            return;
        }

        // Per ogni gruppo di lavoro, avvia un'istanza del batch launcher.
        for (AggregateResult ar : workGroups) {
            String batchClassName = (String) ar.get('Batch_Class_Name__c');
            String paramsHash = (String) ar.get('Params_Hash__c');

            // Il launcher si occuperà di raccogliere gli ID e avviare il batch finale.
            ResubmissionLauncherBatch launcher = new ResubmissionLauncherBatch(batchClassName, paramsHash);
            Database.executeBatch(launcher, 2000); // Il launcher processa gli item, non i record finali.
        }
    }
}