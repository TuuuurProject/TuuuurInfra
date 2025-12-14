# Configuration DNS OVH avec Terraform

## 📋 Prérequis

1. **Créer des credentials OVH API**

   Allez sur : https://eu.api.ovh.com/createToken/

   Remplissez :

   - **Application name**: `terraform-tuuuur`
   - **Application description**: `Gestion DNS pour Terraform`
   - **Validity**: `Unlimited`

   Accordez ces droits :

   ```
   GET    /domain/zone/*
   POST   /domain/zone/*
   PUT    /domain/zone/*
   DELETE /domain/zone/*
   ```

   Vous obtiendrez 3 clés :

   - Application Key
   - Application Secret
   - Consumer Key

2. **Configurer vos credentials**

   Éditez `ovh_credentials.tfvars` :

   ```terraform
   ovh_domain             = "votre-domaine.com"
   ovh_application_key    = "votre_app_key"
   ovh_application_secret = "votre_app_secret"
   ovh_consumer_key       = "votre_consumer_key"
   ```

3. **Mettre à jour terraform.tfvars**

   ```terraform
   front_domain = "preprod.votre-domaine.com"
   api_domain   = "api-preprod.votre-domaine.com"
   ```

## 🚀 Déploiement

```bash
# Initialiser Terraform avec le provider OVH
terraform init

# Planifier avec les credentials OVH
terraform plan -var-file="terraform.tfvars" -var-file="ovh_credentials.tfvars"

# Appliquer
terraform apply -var-file="terraform.tfvars" -var-file="ovh_credentials.tfvars"
```

## ✅ Vérification

Après le déploiement :

```bash
# Vérifier que les DNS ont été créés
terraform output

# Tester la résolution DNS
dig preprod.votre-domaine.com +short
dig api-preprod.votre-domaine.com +short

# Vérifier les certificats SSL
gcloud compute ssl-certificates list
```

Le certificat SSL prendra 15-60 minutes pour être actif.

## 🔒 Sécurité

⚠️ **IMPORTANT** : Le fichier `ovh_credentials.tfvars` contient des données sensibles.

- Il est déjà dans `.gitignore`
- **NE JAMAIS** le committer sur Git
- Utilisez un gestionnaire de secrets en production (Vault, Secret Manager, etc.)

## 🔄 Désactiver OVH DNS

Si vous voulez gérer les DNS manuellement :

1. Dans `ovh_credentials.tfvars`, commentez ou supprimez `ovh_domain`
2. Relancez `terraform apply`
