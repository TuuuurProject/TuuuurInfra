# Plateforme Web GCP (Terraform) — Cloud Run (Front + API), SQL Server, Redis, Bastion IAP, réseau privé

Cette repo Terraform déploie une plateforme **orientée production** sur **Google Cloud** :

- **Cloud Run Front (Node.js)** exposé publiquement via **External HTTP(S) Load Balancer** + **certificat TLS géré** + **DNS optionnel**
- **Cloud Run API (.NET 8)** exposé via son **propre** External HTTP(S) Load Balancer + TLS géré
- **Cloud SQL for SQL Server** en **Private IP** (option managée) **ou** **VM SQL Server** (fallback)
- **Memorystore for Redis** en réseau privé
- **Bastion Compute Engine** (Linux) dans un subnet `admin`, **sans IP publique**, accessible via **IAP TCP forwarding** (SSH)
- **VPC dédiée**, subnets, règles firewall minimales et strictes
- **Secret Manager** pour les secrets utilisés par Cloud Run (injection native Cloud Run)
- Structure multi-env : `environments/dev|stage|prod`

> Par défaut : `europe-west1` (modifiable).

---

## Schéma logique (flux & dépendances)

```
Internet
  |
  | HTTPS (Front domain)                    HTTPS (API domain)
  v                                         v
[External HTTPS LB - Front]             [External HTTPS LB - API]
  |  (Serverless NEG)                      |  (Serverless NEG)
  v                                         v
[Cloud Run Front]  -- HTTPS -->        [Cloud Run API]
  |                                         |
  | (VPC Access: PRIVATE_RANGES_ONLY)       | (VPC Access: PRIVATE_RANGES_ONLY)
  v                                         v
------------------------- VPC (custom) -------------------------
   Subnet app (europe-west1)             Subnet admin (europe-west1)
       |                                      |
       |                                      | SSH via IAP (35.235.240.0/20)
       v                                      v
 [Serverless VPC Access Connector]       [Bastion VM (no ext IP)]
       |
       +--> [Memorystore Redis (private IP)]
       |
       +--> [Cloud SQL for SQL Server (private IP via PSA/VPC peering)]
             (ou VM SQL Server fallback, private, port 1433)
----------------------------------------------------------------
```

- L’utilisateur appelle **uniquement** le LB du **Front**.
- Le Front appelle l’API **uniquement via** le **LB de l’API** (pas d’appel direct au service Cloud Run).
- L’API accède à Redis et SQL Server **en privé** (VPC + VPC Access).

---

## Pré-requis

- Terraform >= 1.6
- `gcloud` authentifié (Application Default Credentials) :
  ```bash
  gcloud auth application-default login
  ```
- Un projet GCP, et un domaine (ou sous-domaines) pour :
  - `front_domain` (ex. `app.example.com`)
  - `api_domain` (ex. `api.example.com`)
- (Optionnel) Cloud DNS zone existante si vous voulez que Terraform crée les enregistrements A.

---

## Démarrage rapide

### 1) Choisir un environnement

Exemple avec `dev` :

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars
# éditez terraform.tfvars (project_id, domaines, images, etc.)
terraform init
terraform plan
terraform apply
```

### 2) DNS (pour que le TLS Google-Managed devienne ACTIF)

- Si `create_dns_records=true` et `dns_zone_name` est renseigné, Terraform crée les `A records`.
- Sinon, créez manuellement des enregistrements `A` vers les IP retournées en outputs :
  - `front_lb_ip`
  - `api_lb_ip`

Tant que le DNS ne pointe pas correctement, le certificat restera en `PROVISIONING` (normal).

---

## Sécurité & bonnes pratiques

- Cloud Run utilise :
  - `ingress = INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` (trafic uniquement via Cloud Load Balancing)
  - `default_uri_disabled = true` (désactive l’URL par défaut `*.run.app`)
  - `invoker_iam_disabled = true` (équivalent “unauthenticated” mais **uniquement via LB**)
- Bastion :
  - **pas d’IP publique**
  - SSH via **IAP TCP forwarding** (plage IP `35.235.240.0/20`)
  - Optionnel : OS Login + IAM (préconfiguré côté Terraform)
- Secrets :
  - Injection Cloud Run depuis Secret Manager (les containers ne voient pas les valeurs dans l’IaC).
  - ⚠️ Si vous laissez Terraform **gérer les valeurs** des secrets (`create_versions=true`),
    elles seront présentes dans le state Terraform. Protégez le state (bucket GCS + IAM strict).

---

## Coûts (principes appliqués)

- Cloud Run : min instances = 0, CPU throttling (`cpu_idle=true`), autoscaling, concurrency paramétrable.
- Redis : taille minimale viable (par défaut 1GB, tier BASIC).
- SQL Server :
  - Option 1 (managée) : Cloud SQL for SQL Server (Private IP) — simple/robuste, mais souvent coûteux.
  - Option 2 (fallback) : VM SQL Server (Windows + image SQL PAYG) — potentiellement moins chère à petite échelle
    mais implique patching/backup/ops.
- Bastion : petite VM e2-micro, et vous pouvez la stopper hors horaires.

---

## Structure du repo

```
modules/
  project_services/     # activation APIs
  network/              # VPC + subnets + firewall + PSA
  vpc_connector/        # Serverless VPC Access Connector
  secrets/              # Secret Manager + IAM accessors
  cloudrun_service/     # Cloud Run v2 (paramétrable, secrets env, VPC access)
  lb_serverless/        # External HTTPS LB + serverless NEG + cert géré + DNS optionnel
  redis/                # Memorystore Redis
  sqlserver/            # Cloud SQL SQL Server (private) ou VM SQL Server fallback
  bastion/              # Bastion + IAP IAM + OS Login (optionnel)
environments/
  dev/
  stage/
  prod/
```

---

## Notes d’implémentation

- Le module `network` configure **Private Services Access** (PSA) pour Cloud SQL Private IP (VPC peering).
- Pour Memorystore Redis, la connexion est **privée** via VPC.
- Le VPC Access Connector et les services Cloud Run doivent être dans la **même région**.

---

## Connexion au bastion (IAP)

Après `apply`, utilisez :

```bash
gcloud compute ssh <bastion_name> \
  --tunnel-through-iap \
  --zone <zone> \
  --project <project_id>
```

---

## Variables principales (par environnement)

Voir `environments/*/terraform.tfvars.example`.
