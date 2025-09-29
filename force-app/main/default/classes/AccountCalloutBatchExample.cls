/**
 * @description Esempio di un batch specifico per Account che è compatibile
 * con il framework di risottomissione.
 * Esegue un finto callout per ogni Account.
 */
public class AccountCalloutBatchExample implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    // --- INIZIO CONVENZIONI PER IL FRAMEWORK ---

    /**
     * @description Variabile pubblica per ricevere la lista di ID.
     * Il nome 'recordIdsToProcess' è obbligatorio per il framework.
     */
    public List<Id> recordIdsToProcess;

    /**
     * @description Variabile pubblica per ricevere l'ID del job del launcher.
     * Necessario per aggiornare lo stato finale degli item.
     */
    public String frameworkJobId;

    /**
     * @description Esempi di altri parametri che possono essere passati
     * tramite il JSON di configurazione.
     */
    public String endpoint;
    public Integer timeout;

    // --- FINE CONVENZIONI ---

    // Lista per tenere traccia degli errori
    private List<String> errorMessages = new List<String>();

    /**
     * @description Costruttore vuoto, OBBLIGATORIO per il framework.
     */
    public AccountCalloutBatchExample() {}


    public Database.QueryLocator start(Database.BatchableContext context) {
        // Aggiunto controllo di sicurezza per garantire che la lista non sia mai null
        if (this.errorMessages == null) {
            this.errorMessages = new List<String>();
        }

        // La logica è cambiata: ora esegue una query usando gli ID forniti dal framework.
        if (recordIdsToProcess == null || recordIdsToProcess.isEmpty()) {
            return Database.getQueryLocator([SELECT Id FROM Account WHERE Id = NULL]);
        }
        return Database.getQueryLocator([
            SELECT Id, Name
            FROM Account
            WHERE Id IN :recordIdsToProcess
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Account> scope) {
        // Simula un'operazione di callout per ogni record
        for(Account acc : scope) {
            try {
                // Esegui la tua logica di business qui (es. callout)
                System.debug('Processando Account: ' + acc.Name);
                // throw new CalloutException('Simulazione Errore'); // Decommenta per testare il caso di errore
            } catch (Exception e) {
                errorMessages.add('Errore processando l\'Account ' + acc.Id + ': ' + e.getMessage());
            }
        }
    }

    /**
     * @description Metodo finish: Aggiorna lo stato degli item di risottomissione.
     */
    public void finish(Database.BatchableContext bc) {
        // Se non abbiamo l'ID del job del launcher, non possiamo aggiornare lo stato.
        if (String.isBlank(frameworkJobId)) {
            System.debug('frameworkJobId non fornito, impossibile aggiornare gli item di risottomissione.');
            return;
        }

        // Determina lo stato finale in base agli errori riscontrati
        String finalStatus = errorMessages.isEmpty() ? 'Completed' : 'Error';
        String finalErrorMessage = errorMessages.isEmpty() ? null : String.join(errorMessages, '\n');
        
        // Trova tutti gli item originali processati da questo job
        List<Batch_Resubmission_Item__c> itemsToUpdate = [
            SELECT Id
            FROM Batch_Resubmission_Item__c
            WHERE Batch_Job_Id__c = :frameworkJobId
        ];

        for(Batch_Resubmission_Item__c item : itemsToUpdate) {
            item.Status__c = finalStatus;
            item.Error_Message__c = finalErrorMessage;
        }

        try {
            update itemsToUpdate;
            System.debug('Aggiornati ' + itemsToUpdate.size() + ' item a ' + finalStatus);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Errore durante l\'aggiornamento finale degli item: ' + e.getMessage());
        }
    }
}