# Configuration API - Variables d'environnement

## Variables ajoutées

Toutes les variables d'environnement nécessaires pour votre API .NET ont été configurées automatiquement dans Terraform.

### 1. Connection Strings

#### SQL Server

```
ConnectionStrings__Tuuuur = Server={IP_PRIVÉE},1433;Database={DB_NAME};User Id={DB_USER};Password={DB_PASSWORD};TrustServerCertificate=True;
```

#### Redis

```
ConnectionStrings__Redis = {REDIS_HOST}:{REDIS_PORT}[,password={PASSWORD}]
```

### 2. JWT Configuration

```
JwtSettings__Key = {JWT_KEY}
```

**⚠️ Important:** Générez une clé sécurisée d'au moins 32 caractères.

Exemple de génération avec OpenSSL:

```bash
openssl rand -base64 32
```

### 3. Google OAuth

```
Authentification__Google__ClientId = {GOOGLE_CLIENT_ID}
```

**Configuration requise:**

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Créez des identifiants OAuth 2.0
3. Configurez les origines autorisées:
   - `https://stage.tuuuur.florent-dubut.fr.com`
   - `https://tuuuur.florent-dubut.fr.com`
4. Copiez le Client ID

### 4. Configuration SMTP

```
SmtpEmailConfiguration__FromAddress  = {FROM_EMAIL}
SmtpEmailConfiguration__FromName     = {FROM_NAME}
SmtpEmailConfiguration__SmtpAddress  = {SMTP_HOST}
SmtpEmailConfiguration__SmtpPort     = {SMTP_PORT}
SmtpEmailConfiguration__SmtpLogin    = {SMTP_USER}
SmtpEmailConfiguration__SmtpPassword = {SMTP_PASSWORD}
```

**Providers SMTP recommandés:**

#### Gmail

```
smtp_host = "smtp.gmail.com"
smtp_port = 587
smtp_user = "your-email@gmail.com"
smtp_password = "app-password"  # Créez un mot de passe d'application
```

**Note:** Pour Gmail, activez la validation en 2 étapes puis créez un mot de passe d'application:
https://myaccount.google.com/apppasswords

#### SendGrid

```
smtp_host = "smtp.sendgrid.net"
smtp_port = 587
smtp_user = "apikey"
smtp_password = "SG.xxxxxxxxxxxxx"  # Votre API Key SendGrid
```

#### Mailgun

```
smtp_host = "smtp.eu.mailgun.org"  # ou smtp.mailgun.org pour US
smtp_port = 587
smtp_user = "postmaster@your-domain.mailgun.org"
smtp_password = "your-mailgun-password"
```

## Configuration dans terraform.tfvars

Éditez `/Users/florentdubut/Documents/M2/TuuuurInfra/environments/stage/terraform.tfvars`:

```hcl
# API Configuration
jwt_key            = "GÉNÉRÉ_AVEC_OPENSSL_RAND_BASE64_32"
google_client_id   = "123456789-xxxxxxxxxxxxx.apps.googleusercontent.com"

# SMTP Configuration
smtp_from_address = "noreply@tuuuur.com"
smtp_from_name    = "Tuuuur Platform"
smtp_host         = "smtp.gmail.com"
smtp_port         = 587
smtp_user         = "noreply@tuuuur.com"
smtp_password     = "your-app-password-here"
```

## Variables sensibles

Les variables suivantes sont marquées comme **sensibles** et ne seront pas affichées dans les logs Terraform:

- `jwt_key`
- `smtp_password`
- `db_password`
- `sql_root_password`

**⚠️ Sécurité:**

- Ces valeurs seront stockées dans le Terraform state
- Ne commitez JAMAIS `terraform.tfvars` dans Git (déjà dans `.gitignore`)
- Utilisez des mots de passe forts et uniques
- En production, utilisez Google Secret Manager au lieu de variables d'environnement directes

## Vérification

Après configuration, vérifiez avec:

```bash
cd /Users/florentdubut/Documents/M2/TuuuurInfra/environments/stage
terraform plan -var-file="terraform.tfvars" -var-file="ovh_credentials.tfvars"
```

Les variables d'environnement apparaîtront comme `(sensitive value)` dans le plan.

## Déploiement

```bash
terraform apply -var-file="terraform.tfvars" -var-file="ovh_credentials.tfvars"
```

Vos variables seront automatiquement injectées dans votre container Cloud Run API! 🚀
