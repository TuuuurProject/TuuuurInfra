# Fix SQL Server Permissions

## Problème

L'API renvoie une erreur lors du health check :

```
Cannot open database "appdb" requested by the login. The login failed.
Login failed for user 'appuser'.
```

## Cause

Cloud SQL pour SQL Server crée le **login** au niveau serveur via Terraform, mais ne crée pas automatiquement l'**utilisateur** au niveau de la base de données avec les bonnes permissions.

## Solution Terraform

### Étape 1 : Appliquer la configuration actuelle

```bash
cd environments/preprod
terraform init
terraform apply
```

Cette commande va créer :

- L'instance Cloud SQL
- La base de données `appdb`
- Le login `appuser` au niveau serveur

### Étape 2 : Récupérer les commandes SQL

Après le `terraform apply`, Terraform affichera les commandes SQL à exécuter :

```bash
terraform output manual_sql_commands
```

Ou récupérez la commande de connexion :

```bash
terraform output connection_command
```

### Étape 3 : Se connecter et exécuter les commandes SQL

```bash
# Se connecter à Cloud SQL
gcloud sql connect webplat-preprod-sql --user=sqlserver --database=master

# Entrez le mot de passe root (sql_root_password dans terraform.tfvars)
```

Une fois connecté, copiez/collez le script SQL affiché par `terraform output manual_sql_commands`, ou exécutez manuellement :

```sql
USE [master];
GO

-- Vérifier que le login existe
SELECT name FROM sys.server_principals WHERE name = 'appuser';
GO

-- Passer à la base de données
USE [appdb];
GO

-- Créer l'utilisateur dans la base de données
IF NOT EXISTS (SELECT name FROM sys.database_principals WHERE name = 'appuser')
BEGIN
    CREATE USER [appuser] FOR LOGIN [appuser];
END
GO

-- Donner les permissions db_owner (accès complet à la base)
ALTER ROLE db_owner ADD MEMBER [appuser];
GO

-- Vérifier les permissions
SELECT
    dp.name AS UserName,
    r.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = 'appuser';
GO
```

### Étape 4 : Tester l'API

```bash
curl https://preprod.tuuuur.api.florent-dubut.fr/health
```

Vous devriez maintenant voir `"status": "Healthy"`.

## Solution automatique (optionnel)

Pour automatiser cette configuration via Terraform dans le futur :

### 1. Démarrer Cloud SQL Proxy

```bash
# Télécharger Cloud SQL Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.darwin.amd64
chmod +x cloud-sql-proxy

# Démarrer le proxy
./cloud-sql-proxy --port 1433 tuuuur:europe-west9:webplat-preprod-sql &
```

### 2. Activer le provider MSSQL

Dans `modules/sqlserver/providers.tf`, décommentez :

```hcl
terraform {
  required_providers {
    mssql = {
      source  = "betr-io/mssql"
      version = "~> 0.3.0"
    }
  }
}

provider "mssql" {
  hostname = "127.0.0.1"
  port     = 1433
  username = "sqlserver"
  password = var.root_password
}
```

### 3. Activer les ressources MSSQL

Dans `modules/sqlserver/main.tf`, décommentez les ressources `mssql_user` et `mssql_database_role`.

### 4. Ajouter la variable

Dans `environments/preprod/main.tf`, ajoutez au module sql :

```hcl
module "sql" {
  source = "../../modules/sqlserver"
  # ... autres paramètres ...

  configure_permissions = true  # Activer la configuration automatique
}
```

### 5. Ré-appliquer Terraform

```bash
terraform init -upgrade
terraform apply
```

Les permissions seront maintenant configurées automatiquement !

## Notes importantes

1. **Sécurité** : Le mot de passe SQL est stocké en clair dans le state Terraform. Utilisez un backend sécurisé (GCS avec encryption).

2. **Cloud SQL Proxy** : Nécessaire pour que Terraform puisse exécuter des commandes SQL sur l'instance privée.

3. **Alternative manuelle** : La méthode manuelle (Étapes 1-4) fonctionne toujours et ne nécessite pas Cloud SQL Proxy.

## Troubleshooting

### Impossible de se connecter à Cloud SQL

```bash
# Vérifier que l'instance est accessible
gcloud sql instances describe webplat-preprod-sql

# Vérifier l'IP privée
gcloud sql instances describe webplat-preprod-sql --format="get(ipAddresses)"
```

### Le login n'existe pas

Si le login `appuser` n'existe pas au niveau serveur :

```sql
USE [master];
GO

CREATE LOGIN [appuser] WITH PASSWORD = 'VOTRE_MOT_DE_PASSE';
GO
```

Remplacez `VOTRE_MOT_DE_PASSE` par la valeur de `db_password` dans `terraform.tfvars`.
