# Tuuur Infra (Terraform)

## 🌍 Contexte
Ce projet déploie sur **Google Cloud Platform (GCP)** l’infrastructure pour **Tuuur**, un site de quiz de culture générale en ligne.  
L’architecture est conçue pour être **scalable, sécurisée et modulaire**.

---

## 🏗️ Ce qui est créé
### Réseau
- **VPCs** :
  - `frontend` (héberge les serveurs web visibles depuis Internet)
  - `backend` (héberge l’API / logique du jeu)
  - `bastion` (point d’entrée sécurisé en SSH)
- **Sous-réseaux** pour chaque VPC
- **Peering** entre VPCs (permet aux réseaux de communiquer)
- **Firewalls** :
  - Internet → Frontend (HTTP 80)
  - Frontend → Backend (port 8080)
  - SSH autorisé uniquement via Bastion

### Compute
- **Bastion VM** : petite VM avec IP publique pour se connecter au reste de l’infra
- **Frontend MIG (Managed Instance Group)** :
  - Modèle d’instance basé sur **Nginx**
  - Autoscaling **2 → 10 VMs**
  - Sert le site web sur **port 80**
- **Backend MIG (Managed Instance Group)** :
  - Modèle d’instance basé sur **Node.js**
  - Autoscaling **1 → 10 VMs**
  - Sert l’API sur **port 8080**

### Load Balancer
- **1 seul Load Balancer HTTP global**
  - `/` → frontend
  - `/api/*` → backend
- Fournit une **IP publique unique** pour accéder au site et à l’API

### Base de données
- **Cloud SQL (MySQL 8.0)** :
  - Instance avec sauvegardes automatiques
  - Base `tuuur_db` et utilisateur `tuuur_user`
  - Mot de passe généré automatiquement

### Sécurité
- **Secret Manager** : stocke le mot de passe SQL (`tuuur-sql-user-password`)
- **Service Account applicatif** :
  - Accès à **Secret Manager**
  - Accès en tant que **Client Cloud SQL**

---

## ⚙️ Déploiement

### Prérequis
- **Terraform >= 1.6**
- **gcloud** installé et authentifié (`gcloud auth application-default login`)
- Une clé SSH publique à `~/.ssh/id_ed25519.pub`

### Étapes
1. Clone ou télécharge le projet
2. Ouvre `modules/global_constants/outputs.tf`
   - Remplace `REPLACE_WITH_YOUR_GCP_PROJECT_ID` par ton **ID de projet GCP**
   - Vérifie `region` et `zone` (défaut : `europe-west1 / europe-west1-b`)
3. Initialise Terraform :
   ```bash
   terraform init
   ```
4. Vérifie le plan :
   ```bash
   terraform plan
   ```
5. Applique :
   ```bash
   terraform apply
   ```

---

## 🚀 Résultats

Après `terraform apply` :
- `site_url` → IP publique du Load Balancer
  - `http://<IP>/` : site frontend
  - `http://<IP>/api/` : API backend
- `sql_connection_name` + `sql_public_ip` → pour connecter un client SQL
- `sql_user_secret` → nom du secret GCP contenant le mot de passe SQL
 facilement remplacer les startup scripts par un déploiement Docker/Artifact Registry.