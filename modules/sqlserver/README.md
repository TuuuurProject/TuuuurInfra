# Module SQL Server

Ce module gère les instances SQL Server via Cloud SQL ou VM.

## Configuration des permissions

Ce module utilise le provider `mssql` pour configurer automatiquement les permissions de l'utilisateur de base de données.

### Prérequis pour Cloud SQL

Pour que le provider MSSQL puisse se connecter à Cloud SQL, vous avez **deux options** :

#### Option 1 : Cloud SQL Proxy (Recommandé)

Démarrez Cloud SQL Proxy avant d'exécuter Terraform :

```bash
# Télécharger Cloud SQL Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.amd64
chmod +x cloud-sql-proxy

# Démarrer le proxy (remplacez par votre connection name)
./cloud-sql-proxy --port 1433 PROJECT_ID:REGION:INSTANCE_NAME &

# Puis dans providers.tf du module, utilisez :
# hostname = "127.0.0.1"
```

#### Option 2 : Connexion via Private IP (Si VPN/Bastion configuré)

Si vous avez un VPN ou un bastion configuré avec accès au VPC privé :

```bash
# Exécutez Terraform depuis une machine ayant accès au VPC privé
# Le provider MSSQL utilisera directement l'IP privée de l'instance
```

### Configuration du provider dans providers.tf

Modifiez le fichier `modules/sqlserver/providers.tf` selon votre méthode :

**Pour Cloud SQL Proxy :**

```hcl
provider "mssql" {
  hostname = "127.0.0.1"  # Cloud SQL Proxy en local
  port     = 1433
  username = "sqlserver"
  password = var.root_password
}
```

**Pour Private IP :**

```hcl
provider "mssql" {
  hostname = var.mode == "cloudsql" && length(google_sql_database_instance.sql) > 0 ? google_sql_database_instance.sql[0].private_ip_address : null
  port     = 1433
  username = "sqlserver"
  password = var.root_password
}
```

## Déploiement

1. **Initialisez le provider MSSQL** :

   ```bash
   cd environments/preprod
   terraform init
   ```

2. **Démarrez Cloud SQL Proxy** (si Option 1) :

   ```bash
   ./cloud-sql-proxy --port 1433 tuuuur:europe-west9:webplat-preprod-sql &
   ```

3. **Appliquez la configuration** :
   ```bash
   terraform apply
   ```

## Ressources créées

- `google_sql_database_instance` : Instance Cloud SQL SQL Server
- `google_sql_database` : Base de données
- `google_sql_user` : Utilisateur (login au niveau serveur)
- `mssql_user` : Utilisateur au niveau base de données
- `mssql_database_role` : Attribution du rôle db_owner

## Troubleshooting

### Le provider MSSQL ne peut pas se connecter

**Erreur** : `Error: unable to connect to database server`

**Solutions** :

1. Vérifiez que Cloud SQL Proxy est démarré : `ps aux | grep cloud-sql-proxy`
2. Vérifiez que l'instance Cloud SQL est accessible
3. Vérifiez le mot de passe root dans `terraform.tfvars`

### L'utilisateur n'a toujours pas les permissions

Si après le apply l'utilisateur n'a pas les bonnes permissions, vérifiez manuellement :

```sql
-- Connectez-vous
gcloud sql connect webplat-preprod-sql --user=sqlserver --database=appdb

-- Vérifiez les rôles
SELECT
    dp.name AS UserName,
    r.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = 'appuser';
```

### Solution de secours manuelle

Si le provider MSSQL ne fonctionne pas, vous pouvez configurer les permissions manuellement :

```bash
gcloud sql connect webplat-preprod-sql --user=sqlserver --database=master

# Puis dans SQL Server :
USE [appdb];
GO

CREATE USER [appuser] FOR LOGIN [appuser];
GO

ALTER ROLE db_owner ADD MEMBER [appuser];
GO
```
