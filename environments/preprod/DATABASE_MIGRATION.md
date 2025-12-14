# Migration Automatique SQL Server via Cloud Run Job

## Vue d'ensemble

Ce module configure automatiquement la migration de la base de données SQL Server en utilisant :

- **Cloud Run Job** : Exécute l'image Docker de migration
- **Image Docker** : Contient `sqlpackage` et votre DACPAC (.NET SQL Database Project)
- **VPC Connector** : Permet au job d'accéder à Cloud SQL en privé

## Architecture

```
Terraform Apply
  │
  ├─> Crée Cloud SQL Instance
  ├─> Crée la base de données
  ├─> Crée l'utilisateur SQL
  │
  ├─> Crée Cloud Run Job (migration)
  │   └─> Image: europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod
  │       └─> Variables: DB_SERVER, DB_NAME, DB_USER, DB_PASSWORD
  │       └─> VPC Access: VPC Connector (connexion privée)
  │
  └─> Exécute automatiquement le job
      └─> sqlpackage applique le DACPAC
          ├─> Crée les tables
          ├─> Crée les procédures stockées
          ├─> Configure les permissions
          └─> Applique les migrations
```

## Configuration

### Dans terraform.tfvars

```hcl
# Activer la migration automatique
run_db_migration  = true

# Image Docker contenant sqlpackage et votre DACPAC
db_migration_image = "europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod"
```

### Image Docker requise

Votre image Docker doit :

1. Contenir `sqlpackage` (outil de migration SQL Server)
2. Contenir votre fichier `.dacpac` compilé
3. Accepter ces variables d'environnement :
   - `DB_SERVER` : Adresse IP privée de Cloud SQL
   - `DB_NAME` : Nom de la base de données
   - `DB_USER` : Utilisateur SQL
   - `DB_PASSWORD` : Mot de passe

**Exemple de Dockerfile** (déjà dans votre projet) :

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS migrate
WORKDIR /src

# Copier et compiler le projet SQL
COPY ["src/Tuuuur.Database/Tuuuur.Database.sqlproj", "Tuuuur.Database/"]
COPY src/Tuuuur.Database/ Tuuuur.Database/
RUN dotnet restore "Tuuuur.Database/Tuuuur.Database.sqlproj"
RUN dotnet build "Tuuuur.Database/Tuuuur.Database.sqlproj" -c Release

# Installer sqlpackage
RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget https://aka.ms/sqlpackage-linux -O sqlpackage.zip && \
    unzip sqlpackage.zip -d /opt/sqlpackage && \
    chmod +x /opt/sqlpackage/sqlpackage && \
    rm sqlpackage.zip

ENV PATH="$PATH:/opt/sqlpackage"

# Commande de migration
CMD ["sh", "-c", "sqlpackage /Action:Publish /SourceFile:Tuuuur.Database/bin/Release/Tuuuur.Database.dacpac /TargetServerName:$DB_SERVER /TargetDatabaseName:$DB_NAME /TargetUser:$DB_USER /TargetPassword:$DB_PASSWORD /TargetEncryptConnection:False /TargetTrustServerCertificate:True /p:DropObjectsNotInSource=True /p:BlockOnPossibleDataLoss=False"]
```

## Déploiement

### 1. Première fois (création complète)

```bash
cd environments/preprod

# Initialiser Terraform
terraform init

# Appliquer la configuration
terraform apply
```

Terraform va :

1. Créer l'infrastructure (VPC, Cloud SQL, etc.)
2. Créer le Cloud Run Job de migration
3. **Exécuter automatiquement la migration** (via `null_resource`)

### 2. Vérifier la migration

```bash
# Voir les logs du job
terraform output run_migration_command
# Copier/coller la commande affichée

# Ou via la console
terraform output db_migration_job_url
# Ouvrir l'URL dans le navigateur
```

### 3. Ré-exécuter la migration manuellement

Si vous mettez à jour votre schéma SQL :

```bash
# Option 1 : Via Terraform output
terraform output -raw run_migration_command | sh

# Option 2 : Commande directe
gcloud run jobs execute webplat-preprod-db-migration \
  --region=europe-west9 \
  --project=tuuuur \
  --wait
```

## Fonctionnement détaillé

### Variables passées au container

Le Cloud Run Job reçoit automatiquement :

```bash
DB_SERVER=10.x.x.x          # IP privée de Cloud SQL
DB_NAME=appdb               # Nom de la base
DB_USER=appuser             # Utilisateur
DB_PASSWORD=***             # Mot de passe (depuis terraform.tfvars)
```

### Permissions automatiques

Le DACPAC SQL Server gère automatiquement :

- Création des tables
- Création des vues
- Création des procédures stockées
- **Création de l'utilisateur dans la base de données**
- **Attribution des rôles (db_owner, etc.)**

Cela **résout le problème de permissions** mentionné dans `FIX_SQL_PERMISSIONS.md` !

### Connexion VPC privée

Le job utilise le VPC Connector pour accéder à Cloud SQL en privé :

- Pas d'IP publique nécessaire sur Cloud SQL
- Communication sécurisée via le VPC
- Egress `PRIVATE_RANGES_ONLY` pour optimiser les coûts

## Avantages

✅ **Automatique** : La migration s'exécute automatiquement au déploiement  
✅ **Reproductible** : Même processus pour tous les environnements  
✅ **Permissions** : Le DACPAC configure automatiquement les permissions  
✅ **Infrastructure as Code** : Tout est dans Terraform  
✅ **Idempotent** : Peut être ré-exécuté sans danger  
✅ **Logs** : Consultables dans Cloud Run

## Désactivation (optionnel)

Si vous préférez gérer la migration manuellement :

```hcl
# Dans terraform.tfvars
run_db_migration = false
```

Ou supprimez la variable `db_migration_image`.

## Troubleshooting

### Le job échoue avec "Cannot connect to database"

**Cause** : Le VPC Connector n'est pas correctement configuré ou l'IP n'est pas accessible.

**Solution** :

```bash
# Vérifier l'IP privée de Cloud SQL
terraform output sql_private_ip

# Vérifier que le VPC Connector existe
gcloud compute networks vpc-access connectors list --region=europe-west9
```

### Le job échoue avec "Login failed for user"

**Cause** : L'utilisateur SQL n'existe pas encore ou le mot de passe est incorrect.

**Solution** : Vérifiez que `db_password` dans `terraform.tfvars` correspond à celui configuré.

### Le job se termine mais le schéma n'est pas à jour

**Cause** : Votre image Docker n'est peut-être pas à jour.

**Solution** :

```bash
# Rebuild et push de l'image
docker build -t europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod .
docker push europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod

# Ré-exécuter le job
terraform output -raw run_migration_command | sh
```

### Voir les logs du job

```bash
# Via gcloud
gcloud run jobs executions list --job=webplat-preprod-db-migration --region=europe-west9

# Logs d'une exécution spécifique
gcloud run jobs executions describe EXECUTION_NAME --region=europe-west9

# Ou via la console
terraform output db_migration_job_url
```

## Mise à jour du schéma

Workflow recommandé :

1. **Modifier votre SQL Database Project** (fichiers `.sql`)
2. **Compiler et publier l'image Docker** :
   ```bash
   docker build -t europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod .
   docker push europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod
   ```
3. **Exécuter la migration** :
   ```bash
   terraform output -raw run_migration_command | sh
   ```

Pas besoin de `terraform apply` à chaque changement de schéma !

## Coûts

- **Cloud Run Job** : Facturation à l'exécution (quelques secondes/minutes)
- **VPC Connector** : ~$10/mois (déjà utilisé par l'API)
- **Artifact Registry** : Storage de l'image (~quelques Mo)

Coût marginal très faible car le job s'exécute seulement lors des déploiements.

## Sécurité

- ✅ Mot de passe stocké dans Terraform state (chiffré avec backend GCS)
- ✅ Communication privée via VPC (pas d'exposition publique)
- ✅ Service Account dédié avec permissions minimales
- ✅ Image Docker depuis Artifact Registry privé

## Exemple complet

```bash
# 1. Configuration initiale
cd environments/preprod
terraform init
terraform apply  # Crée tout + exécute la migration

# 2. Vérifier que tout fonctionne
curl https://preprod.tuuuur.api.florent-dubut.fr/health
# Devrait retourner "status": "Healthy"

# 3. Modifier le schéma SQL (dans votre projet .NET)
# 4. Rebuild l'image
docker build -t europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod .
docker push europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod

# 5. Ré-exécuter la migration
gcloud run jobs execute webplat-preprod-db-migration \
  --region=europe-west9 \
  --project=tuuuur \
  --wait

# 6. Vérifier les changements
curl https://preprod.tuuuur.api.florent-dubut.fr/health
```

Voilà ! Votre base de données est maintenant entièrement gérée via Infrastructure as Code. 🎉
