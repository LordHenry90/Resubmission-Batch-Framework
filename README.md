Data Model

Batch_Resubmission_Item__c
<img width="1011" height="575" alt="image" src="https://github.com/user-attachments/assets/77db1c21-c94d-4b5c-8080-8ca8a1793549" />

Apex Classes

 - ResubmissionHelper.cls (Contiene la logica per creare gli item e calcolare l'hash)
 - ResubmissionScheduler.cls (Lo scheduler che avvia il processo)
 - ResubmissionLauncherBatch.cls (Il batch proxy che avvia il tuo batch specifico)
 - AccountCalloutBatchExample.cls (batch d'esempio che si adatta al framework)
 - ResubmissionHelper_Test.cls
 - AccountCalloutBatch_Test.cls
 - ResubmissionScheduler_Test.cls
 - ResubmissionLauncherBatch_Test.cls

Step 1: Deploy del Framework
- Installa il framework tramite questo link: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tJ7000000osiv

Step 2: Adattamento dei Batch Esistenti
- Per rendere un tuo batch compatibile con il framework, assicurati che segua queste convenzioni:

- Costruttore Vuoto: La classe deve avere un costruttore pubblico senza argomenti.

   - public MyBatch() {}

- Variabili Pubbliche per i Parametri: I parametri che erano nel costruttore devono diventare variabili pubbliche. I nomi devono corrispondere alle chiavi nel JSON.

   - public String endpoint;
   - public Integer timeout;

- Variabile per gli ID: La classe deve avere una variabile pubblica List<Id> chiamata esattamente recordIdsToProcess.

   - public List<Id> recordIdsToProcess;

- Variabile per il Job ID del Framework: La classe deve avere una variabile pubblica String chiamata esattamente frameworkJobId.

   - public String frameworkJobId;

- Logica nel Metodo start: Il metodo start deve usare la lista recordIdsToProcess per costruire un Database.QueryLocator.

   - public Database.QueryLocator start(Database.BatchableContext context) {
       return Database.getQueryLocator([
           SELECT Id, Name FROM Account WHERE Id IN :recordIdsToProcess
       ]);
   }

- Logica nel Metodo finish: Il metodo finish deve usare frameworkJobId per trovare i record Batch_Resubmission_Item__c corrispondenti e aggiornare il loro stato a Completed o Error.

Step 3: Creazione degli Item di Risottomissione (in Blocco)
- Usa la classe ResubmissionHelper per creare in modo sicuro e bulkizzato gli item nella coda.

Esegui questo codice da una finestra di Execute Anonymous per testare:

// 1. Definisci gli ID dei record da risottomettere
   - List<Id> accountIds = new List<Id>{'0015p00002A...', '0015p00002B...'}; // Sostituisci con ID reali

// 2. Definisci il nome della classe batch target
   - String batchClassName = 'AccountCalloutBatch';

// 3. Definisci i parametri di configurazione
   - Map<String, Object> params = new Map<String, Object>{
        'endpoint' => '[https://api.example.com/v1/notify](https://api.example.com/v1/notify)',
        'timeout' => 90000
    };

// 4. Definisci la dimensione del batch (opzionale)
   - Integer batchSize = 10;

// 5. Chiama l'helper per creare gli item
   - ResubmissionHelper.createItems(accountIds, batchClassName, params, batchSize);

   - System.debug('Creati item di risottomissione.');

Step 4: Schedulazione del Job
- Una volta che il framework è configurato, avvia lo scheduler affinché processi la coda a intervalli regolari.

- Esegui questo codice una sola volta dalla finestra di Execute Anonymous:

// Schedula l'esecuzione ogni ora, al minuto 0.
- String cronExpression = '0 0 * * * ?';
- String jobName = 'Resubmission Framework Hourly Job';

// Ferma eventuali job precedenti con lo stesso nome
- List<CronTrigger> existingJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = :jobName];
for (CronTrigger job : existingJobs) {
    System.abortJob(job.Id);
}

// Avvia il nuovo job
- System.schedule(jobName, cronExpression, new ResubmissionScheduler());

- System.debug('Job di risottomissione schedulato con successo.');

Step 5: Monitoraggio
- Puoi monitorare l'esecuzione del framework in due modi:

- Record Batch_Resubmission_Item__c: Controlla i record di questo oggetto. Il loro campo Status__c ti mostrerà se sono New, In Progress, Completed o Error.

- Pagina Apex Jobs: Vai su Setup > Apex Jobs. Qui vedrai l'esecuzione dello scheduler, del ResubmissionLauncherBatch e dei tuoi batch target.
