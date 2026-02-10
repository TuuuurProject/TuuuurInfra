# Tuuuur Infrastructure - Plateforme Web GCP (Terraform)

Infrastructure as Code pour déployer une plateforme web moderne sur **Google Cloud Platform** :

- **Cloud Run Front** (Node.js) + **Cloud Run API** (.NET 8)
- **Cloud SQL for SQL Server** (Private IP) avec migration automatique
- **Memorystore for Redis** (réseau privé)
- **External HTTPS Load Balancers** avec certificats TLS gérés
- **GCP Secret Manager** pour la gestion centralisée des secrets
- **OVH DNS** (optionnel) pour la gestion des domaines
- **VPC dédiée** avec subnets, firewall et Private Services Access
- Structure multi-environnements : `dev`, `preprod`, `prod`

> Région par défaut : `europe-west9` (Paris)

---

## 🏗️ Architecture

```
Internet
  |
  | HTTPS (front.example.com)           HTTPS (api.example.com)  
  v                                      v
[External HTTPS LB + TLS]            [External HTTPS LB + TLS]
  |  (Serverless NEG)                   |  (Serverless NEG)
  v                                      v
[Cloud Run Front]  -- HTTPS -->     [Cloud Run API]
  |                                      |
  | (VPC Access: PRIVATE_RANGES_ONLY)   | (VPC Access: PRIVATE_RANGES_ONLY)
  v                                      v
----------------------- VPC (custom) -----------------------
   Subnet app (europe-west9)        Subnet connector
       |                                |
       v                                v
 [Serverless VPC Access Connector]     |
       |                                |
       +--> [Memorystore Redis (Private IP: 10.x.x.x:6379)]
       |
       +--> [Cloud SQL SQL Server (Private IP via PSA)]
------------------------------------------------------------

[GCP Secret Manager]
  |
  +-> Tous les secrets/configs (DB passwords, JWT, SMTP, images, domains...)
  |
  +-> Lecture par Terraform (module secrets_datasource)
  +-> Injection dans Cloud Run (secrets natifs)
```

**Flux de données** :
1. L'utilisateur accède au **Front** via le Load Balancer (HTTPS)
2. Le Front appelle l'**API** via son Load Balancer (HTTPS)
3. L'API accède à **Redis** et **SQL Server** en privé via VPC Access
4. Tous les secrets sont lus depuis **GCP Secret Manager**

---

## 🔐 Gestion des Secrets (GCP Secret Manager)

### Architecture des Secrets

Tous les secrets et configurations sont stockés dans **GCP Secret Manager** :

**Secrets par environnement** :
- `webplat-preprod-*` (preprod)
- `webplat-prod-*` (prod)

**Types de secrets** :
- **Sensibles** : db-password, sql-root-password, jwt-key, smtp-password, redis-auth, google-client-id
- **Configuration** : region, front-image, api-image, front-domain, api-domain, db-migration-image, ovh-domain
- **OVH** : ovh-application-key, ovh-application-secret, ovh-consumer-key

### Modules de Secrets

1. **`secrets_datasource`** : Lit les secrets depuis GCP Secret Manager
   - Expose deux outputs : `secrets` (sensible) et `config` (non-sensible)
   - Utilisé par tous les modules Terraform

2. **`secrets`** : Crée les secrets manquants (db-password, redis-auth)
   - Génère automatiquement les passwords si non fournis
   - Versions gérées automatiquement

### Initialisation des Secrets

Utilisez le script fourni pour créer/mettre à jour les secrets :

```bash
# Éditer le script avec vos valeurs
vim scripts/push-secrets-to-gcp.sh

# Pour preprod
./scripts/push-secrets-to-gcp.sh preprod

# Pour prod
./scripts/push-secrets-to-gcp.sh prod

# Vérifier
gcloud secrets list --project=tuuuur --filter="name~webplat-preprod"
```

**Secrets gérés** :
- `region` : Région GCP (ex: europe-west9)
- `db-password` : Mot de passe de l'utilisateur SQL
- `sql-root-password` : Mot de passe root SQL Server
- `jwt-key` : Clé JWT pour l'API
- `google-client-id` : OAuth Google Client ID
- `smtp-from-address`, `smtp-from-name`, `smtp-host`, `smtp-user`, `smtp-password` : Configuration SMTP
- `front-image` / `api-image` : Images Docker des services
- `front-domain` / `api-domain` : Domaines des applications
- `db-migration-image` : Image Docker pour la migration DB
- `ovh-domain`, `ovh-application-key`, `ovh-application-secret`, `ovh-consumer-key` : Credentials OVH DNS
- `redis-auth` : Token d'authentification Redis

### Mise à jour des Secrets

**Via gcloud CLI** :
```bash
echo -n "nouvelle-valeur" | gcloud secrets versions add webplat-preprod-db-password \
  --project=tuuuur \
  --data-file=-
```

**Via le script** :
```bash
# Éditer les valeurs dans le script
vim scripts/push-secrets-to-gcp.sh

# Re-pousser les secrets
./scripts/push-secrets-to-gcp.sh preprod
```

**Via GitHub Actions** :
Utilisez le workflow `Update Terraform Images` dans l'UI GitHub pour mettre à jour les images Docker.

---

## 📋 Pré-requis

- **Terraform** >= 1.6.0
- **gcloud CLI** authentifié :
  ```bash
  gcloud auth application-default login
  ```
- **Projet GCP** avec billing activé
- **Domaines** configurés (ou sous-domaines) :
  - Front : `preprod.tuuuur.florent-dubut.fr`
  - API : `preprod.tuuuur.api.florent-dubut.fr`
- **(Optionnel)** Credentials OVH pour DNS automatique

---

## 🚀 Démarrage Rapide

### 1. Initialiser les secrets dans GCP

```bash
# Éditer le script avec vos valeurs
vim scripts/push-secrets-to-gcp.sh

# Pousser les secrets pour preprod
./scripts/push-secrets-to-gcp.sh preprod

# Vérifier
gcloud secrets list --project=tuuuur --filter="name~webplat-preprod"
```

### 2. Configurer l'environnement

```bash
cd environments/preprod

# Copier l'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer les variables (project_id, etc.)
vim terraform.tfvars
```

### 3. Configurer OVH DNS (optionnel)

Si vous utilisez OVH pour gérer vos domaines :

```bash
export OVH_APPLICATION_KEY="your-key"
export OVH_APPLICATION_SECRET="your-secret"
export OVH_CONSUMER_KEY="your-consumer-key"
```

Vous pouvez aussi mettre ces valeurs dans GCP Secret Manager (recommandé).

### 4. Déployer

```bash
terraform init

# Plan
terraform plan -var="project_id=tuuuur" -var="env=preprod"

# Apply
terraform apply -var="project_id=tuuuur" -var="env=preprod"
```

### 5. Attendre l'activation du certificat SSL

Les certificats Google-Managed prennent **15-60 minutes** pour passer de `PROVISIONING` à `ACTIVE`.

Surveiller l'état :
```bash
gcloud compute ssl-certificates list --project=tuuuur \
  --filter="name~webplat-preprod"
```

Une fois `ACTIVE`, vos sites seront accessibles :
- Front : `https://preprod.tuuuur.florent-dubut.fr`
- API : `https://preprod.tuuuur.api.florent-dubut.fr`

---

## 📁 Structure du Projet

```
TuuuurInfra/
├── modules/
│   ├── project_services/      # Activation des APIs GCP
│   ├── network/                # VPC, subnets, firewall, PSA
│   ├── vpc_connector/          # Serverless VPC Access Connector
│   ├── secrets/                # Création de secrets (db-password, redis-auth)
│   ├── secrets_datasource/     # Lecture des secrets depuis GCP Secret Manager
│   ├── cloudrun_service/       # Cloud Run v2 (Front & API)
│   ├── lb_serverless/          # External HTTPS LB + Serverless NEG + TLS
│   ├── redis/                  # Memorystore for Redis
│   ├── sqlserver/              # Cloud SQL SQL Server + Migration automatique
│   └── ovh_dns/                # Gestion DNS OVH (optionnel)
│
├── environments/
│   ├── dev/
│   ├── preprod/
│   │   ├── main.tf              # Configuration principale
│   │   ├── variables.tf         # Définition des variables
│   │   ├── outputs.tf           # Outputs (IPs, URLs, etc.)
│   │   ├── providers.tf         # Providers (Google, OVH)
│   │   ├── versions.tf          # Versions Terraform et providers
│   │   ├── backend.tf           # Backend GCS pour le state
│   │   └── terraform.tfvars.example
│   └── prod/
│
├── scripts/
│   └── push-secrets-to-gcp.sh  # Script de migration des secrets
│
├── .github/
│   ├── workflows/
│   │   ├── cd-preprod.yml      # Déploiement preprod (automatique)
│   │   ├── cd-prod.yml         # Déploiement prod (protection renforcée)
│   │   ├── terraform-apply.yml # Workflow réutilisable
│   │   ├── terraform-plan-pr.yml # Plan automatique sur PRs
│   │   └── update-images.yml   # Mise à jour des images Docker
│   ├── GITHUB_SECRETS.md       # Configuration des secrets GitHub
│   └── WORKFLOWS_GUIDE.md      # Guide d'utilisation des workflows
│
├── destroy-all.sh              # Script de destruction complète
└── README.md                   # Ce fichier
```

---

## 🔧 Variables Principales

Variables configurables dans `terraform.tfvars` :

```hcl
# Projet
project_id = "tuuuur"
env        = "preprod"
app_name   = "webplat"

# Base de données
db_name = "appdb"
db_user = "appuser"

# Migration automatique
run_db_migration = true  # Active la migration automatique

# Scaling Cloud Run
front_min_instances = 0
front_max_instances = 10
api_min_instances   = 0
api_max_instances   = 10

# Redis
redis_memory_size_gb = 1
redis_tier           = "BASIC"  # ou "STANDARD_HA"

# SQL Server
sql_tier             = "db-custom-1-3840"  # 1 vCPU, 3.75 GB RAM
sql_disk_size_gb     = 50
sql_high_availability = false  # true pour production

# DNS (optionnel)
create_dns_records = false  # true si vous utilisez Cloud DNS
dns_zone_name      = ""     # nom de la zone Cloud DNS
```

---

## 🔒 Sécurité & Bonnes Pratiques

### Cloud Run
- ✅ `ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` : Trafic uniquement via Load Balancer
- ✅ `default_uri_disabled = true` : Désactive l'URL `*.run.app` par défaut
- ✅ `invoker_iam_disabled = true` : IAM géré manuellement (allUsers via LB uniquement)
- ✅ VPC Access avec `PRIVATE_RANGES_ONLY` : Accès privé à Redis et SQL
- ✅ Service Accounts dédiés pour Front et API

### Secrets
- ✅ Tous les secrets dans **GCP Secret Manager**
- ✅ Injection native Cloud Run (pas de variables d'environnement en clair)
- ✅ Versioning automatique avec `version = "latest"`
- ✅ IAM strict : Service Accounts ont uniquement `secretAccessor`
- ✅ Séparation sensible/non-sensible via outputs (`secrets` vs `config`)

### Réseau
- ✅ VPC dédiée avec subnets isolés (app + connector)
- ✅ Private Services Access (PSA) pour Cloud SQL
- ✅ Firewall rules minimales et strictes
- ✅ Pas d'IP publique sur les ressources backend
- ✅ VPC Connector pour l'accès Cloud Run → Redis/SQL

### GitHub Actions
- ✅ Seulement **4 secrets GitHub** requis :
  - `GCP_SA_KEY` : Service Account GCP
  - `OVH_APPLICATION_KEY`, `OVH_APPLICATION_SECRET`, `OVH_CONSUMER_KEY` (optionnels)
- ✅ Tous les autres secrets lus depuis GCP Secret Manager
- ✅ Déploiements protégés :
  - Preprod : Confirmation `"deploy"`
  - Prod : Confirmation stricte `"deploy-production"`
- ✅ Plans automatiques sur les Pull Requests

---

## 🚀 Migration Automatique SQL Server

### Cloud Run Job (Automatique)

La migration de la base de données est **entièrement automatisée** via un Cloud Run Job qui exécute votre image Docker de migration (DACPAC).

**Configuration** dans `terraform.tfvars` :

```hcl
run_db_migration   = true
db_migration_image = "europe-west9-docker.pkg.dev/tuuuur/tuuuur/database:preprod"
```

**Ce que fait la migration automatique** :

1. ✅ Crée l'instance Cloud SQL SQL Server
2. ✅ Configure l'utilisateur et les permissions
3. ✅ Exécute automatiquement le Cloud Run Job de migration
4. ✅ Applique le DACPAC (tables, vues, procédures stockées)
5. ✅ Donne les permissions `db_owner` à l'utilisateur

**Ré-exécuter la migration manuellement** :

```bash
gcloud run jobs execute webplat-preprod-db-migration \
  --region=europe-west9 \
  --project=tuuuur \
  --wait
```

**Voir les logs** :

```bash
gcloud run jobs executions list \
  --job=webplat-preprod-db-migration \
  --region=europe-west9 \
  --project=tuuuur
```

---

## 💰 Optimisation des Coûts

### Cloud Run
- **min_instances = 0** : Scale to zero quand pas de trafic
- **cpu_idle = true** : CPU throttling quand idle
- **Autoscaling** : Adapte automatiquement selon la charge
- **Concurrency** : Plusieurs requêtes par instance (Front: 80, API: 40)

### Redis
- **Tier BASIC** : Pas de réplication (dev/preprod)
- **Tier STANDARD_HA** : Haute disponibilité (prod)
- **Taille minimale** : 1 GB pour commencer

### SQL Server
- **Cloud SQL** : Managé, robuste, mais coûteux
  - `db-custom-1-3840` : 1 vCPU, 3.75 GB RAM (~200€/mois)
  - **Optimisation** : Possibilité d'arrêter hors horaires de dev
- **Haute disponibilité** : Désactivée en dev/preprod

### Load Balancers
- **Coût fixe** : ~18€/mois par LB (Front + API = ~36€/mois)
- **Trafic** : Premier 1 TB gratuit par mois en Europe

### Réseau
- **VPC** : Gratuit
- **VPC Connector** : e2-micro instances (~8€/mois)
- **Private Services Access** : Gratuit

**Coût total estimé preprod** : ~250-300€/mois
**Coût total estimé prod** : ~400-500€/mois (avec HA)

---

## 📊 Outputs Terraform

Après `terraform apply`, récupérez les informations importantes :

```bash
terraform output

# Examples d'outputs :
# front_lb_ip         = "34.36.81.221"
# api_lb_ip           = "34.110.184.67"
# front_url           = "https://preprod.tuuuur.florent-dubut.fr"
# api_url             = "https://preprod.tuuuur.api.florent-dubut.fr"
# redis_host          = "10.49.80.251"
# redis_port          = 6379
# sql_instance_name   = "webplat-preprod-sql"
# sql_private_ip      = "10.16.0.3"
```

---

## 🔄 CI/CD avec GitHub Actions

### Workflows disponibles

1. **CD - Deploy Preprod** (`cd-preprod.yml`)
   - Déclenché sur push vers `release`
   - Ou manuellement (taper `deploy` pour confirmer)

2. **CD - Deploy Production** (`cd-prod.yml`)
   - Déclenché sur push vers `master`
   - Ou manuellement (taper `deploy-production` pour confirmer)

3. **Update Terraform Images** (`update-images.yml`)
   - Met à jour les images Docker dans GCP Secret Manager
   - Déclenche automatiquement le déploiement

4. **Terraform Plan (PR)** (`terraform-plan-pr.yml`)
   - Plan automatique sur les Pull Requests
   - Poste le plan en commentaire sur la PR

### Configuration des secrets GitHub

Voir [.github/GITHUB_SECRETS.md](.github/GITHUB_SECRETS.md) pour les détails.

**Secrets requis** :
- `GCP_SA_KEY` : JSON du service account GCP
- `OVH_APPLICATION_KEY` : (optionnel) Pour OVH DNS
- `OVH_APPLICATION_SECRET` : (optionnel) Pour OVH DNS
- `OVH_CONSUMER_KEY` : (optionnel) Pour OVH DNS

### Guide d'utilisation

Voir [.github/WORKFLOWS_GUIDE.md](.github/WORKFLOWS_GUIDE.md) pour un guide complet.

---

## 🛠️ Commandes Utiles

### Gestion des secrets

```bash
# Lister tous les secrets
gcloud secrets list --project=tuuuur --filter="name~webplat-preprod"

# Voir une version de secret
gcloud secrets versions access latest \
  --secret=webplat-preprod-db-password \
  --project=tuuuur

# Mettre à jour un secret
echo -n "nouvelle-valeur" | gcloud secrets versions add webplat-preprod-jwt-key \
  --project=tuuuur \
  --data-file=-

# Lister les versions d'un secret
gcloud secrets versions list webplat-preprod-db-password --project=tuuuur
```

### Gestion Cloud Run

```bash
# Voir les services
gcloud run services list --region=europe-west9 --project=tuuuur

# Voir les logs
gcloud run services logs read webplat-preprod-front \
  --region=europe-west9 \
  --project=tuuuur

# Voir les révisions
gcloud run revisions list \
  --service=webplat-preprod-api \
  --region=europe-west9 \
  --project=tuuuur
```

### Gestion SQL Server

```bash
# Se connecter à Cloud SQL
gcloud sql connect webplat-preprod-sql \
  --user=appuser \
  --database=appdb

# Voir les bases de données
gcloud sql databases list --instance=webplat-preprod-sql --project=tuuuur

# Voir les backups
gcloud sql backups list --instance=webplat-preprod-sql --project=tuuuur
```

### Gestion Redis

```bash
# Voir l'instance Redis
gcloud redis instances describe webplat-preprod-redis \
  --region=europe-west9 \
  --project=tuuuur

# Tester la connexion (depuis Cloud Shell ou VM avec accès VPC)
redis-cli -h 10.49.80.251 -a "votre-auth-token"
```

### Gestion des certificats SSL

```bash
# Lister les certificats
gcloud compute ssl-certificates list --project=tuuuur

# Voir le statut d'un certificat
gcloud compute ssl-certificates describe \
  webplat-preprod-front-cert-preprod-tuuuur-florent-dubut-fr \
  --project=tuuuur \
  --global
```

---

## 🐛 Troubleshooting

### Le certificat SSL reste en PROVISIONING

**Cause** : Le DNS ne pointe pas vers la bonne IP ou la propagation DNS n'est pas terminée.

**Solution** :
```bash
# Vérifier que le DNS pointe vers la bonne IP
dig +short preprod.tuuuur.florent-dubut.fr

# Comparer avec l'IP du load balancer
terraform output front_lb_ip

# Attendre 15-60 minutes pour la propagation DNS complète
```

### Cloud Run ne démarre pas

**Cause** : Secrets manquants ou versions détruites.

**Solution** :
```bash
# Vérifier que les secrets existent
gcloud secrets list --project=tuuuur --filter="name~webplat-preprod"

# Vérifier les versions
gcloud secrets versions list webplat-preprod-db-password --project=tuuuur

# Si DESTROYED, créer une nouvelle version
echo -n "valeur" | gcloud secrets versions add webplat-preprod-db-password \
  --project=tuuuur \
  --data-file=-
```

### Erreur "403 - invalid application key" (OVH)

**Cause** : Credentials OVH invalides ou manquants.

**Solution** :
```bash
# Vérifier les variables d'environnement
echo $OVH_APPLICATION_KEY
echo $OVH_APPLICATION_SECRET
echo $OVH_CONSUMER_KEY

# Ou commenter le provider OVH dans providers.tf si vous ne l'utilisez pas
```

### Redis inaccessible depuis Cloud Run

**Cause** : VPC Access Connector mal configuré ou réseau incorrect.

**Solution** :
```bash
# Vérifier que le connector existe
gcloud compute networks vpc-access connectors list \
  --region=europe-west9 \
  --project=tuuuur

# Vérifier que Cloud Run utilise le connector
gcloud run services describe webplat-preprod-api \
  --region=europe-west9 \
  --project=tuuuur \
  --format="value(spec.template.spec.vpcAccess.connector)"
```

### SQL Server inaccessible

**Cause** : Service networking connection ou permissions.

**Solution** :
```bash
# Vérifier que Cloud SQL a une IP privée
gcloud sql instances describe webplat-preprod-sql \
  --project=tuuuur \
  --format="value(ipAddresses[0].ipAddress)"

# Vérifier le service networking
gcloud services vpc-peerings list \
  --network=webplat-preprod-vpc \
  --project=tuuuur
```

---

## 🗑️ Destruction de l'Infrastructure

### Destruction complète

```bash
# Utiliser le script de destruction
./destroy-all.sh

# Ou manuellement depuis un environnement
cd environments/preprod
terraform destroy -var="project_id=tuuuur" -var="env=preprod"
```

⚠️ **Attention** : Cela supprimera **toutes** les ressources :
- Cloud Run services
- Load Balancers
- Cloud SQL (et toutes les données !)
- Redis (et toutes les données !)
- VPC et réseaux
- Secrets créés par le module `secrets` (pas `secrets_datasource`)

**Les secrets dans GCP Secret Manager ne sont PAS supprimés automatiquement** pour éviter la perte de données. Supprimez-les manuellement si nécessaire.

---

## 📚 Documentation Complémentaire

- **GitHub Secrets** : [.github/GITHUB_SECRETS.md](.github/GITHUB_SECRETS.md)
- **Workflows Guide** : [.github/WORKFLOWS_GUIDE.md](.github/WORKFLOWS_GUIDE.md)
- **Script de secrets** : [scripts/push-secrets-to-gcp.sh](scripts/push-secrets-to-gcp.sh)

### Ressources GCP

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Cloud SQL for SQL Server](https://cloud.google.com/sql/docs/sqlserver)
- [Memorystore for Redis](https://cloud.google.com/memorystore/docs/redis)
- [Secret Manager](https://cloud.google.com/secret-manager/docs)
- [VPC Access Connector](https://cloud.google.com/vpc/docs/configure-serverless-vpc-access)

---

## 📝 Changelog

### v2.0.0 - Migration GCP Secret Manager (2026-02-10)
- ✅ Migration complète vers GCP Secret Manager
- ✅ Suppression du module bastion (non utilisé)
- ✅ Ajout du module `secrets_datasource` pour lire les secrets
- ✅ Séparation secrets sensibles/configuration
- ✅ Utilisation de `version = "latest"` pour les secrets Cloud Run
- ✅ Mise à jour des workflows GitHub Actions (4 secrets au lieu de 20+)
- ✅ Ajout du script `push-secrets-to-gcp.sh`
- ✅ Documentation complète des workflows et secrets

### v1.0.0 - Version initiale
- ✅ Cloud Run Front + API avec Load Balancers
- ✅ Cloud SQL SQL Server avec migration automatique
- ✅ Memorystore Redis
- ✅ VPC privée avec PSA
- ✅ Secrets via GitHub Actions

---

## 🤝 Contributing

Pour contribuer à ce projet :

1. Créer une branche feature
2. Faire vos modifications
3. Ouvrir une Pull Request vers `release` (preprod) ou `master` (prod)
4. Le workflow `terraform-plan-pr.yml` commentera automatiquement avec le plan
5. Après review et merge, le déploiement se fera automatiquement

---

## 📄 License

Ce projet est privé et propriétaire.

---

## 👥 Support

Pour toute question ou problème, ouvrir une issue ou contacter l'équipe infrastructure.
