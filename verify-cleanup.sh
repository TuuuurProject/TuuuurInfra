#!/bin/bash

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="tuuuur"
REGION="europe-west9"
ENV="stage"
APP_NAME="webplat"
PREFIX="${APP_NAME}-${ENV}"
BASTION_ZONE="europe-west9-b"

# Compteurs
TOTAL_CHECKS=0
RESOURCES_FOUND=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GCP Resource Verification Script${NC}"
echo -e "${BLUE}  Project: ${PROJECT_ID}${NC}"
echo -e "${BLUE}  Prefix: ${PREFIX}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Fonction pour logger
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_found() {
    echo -e "${RED}[✗]${NC} $1"
}

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI n'est pas installé."
    exit 1
fi

# Définir le projet
gcloud config set project ${PROJECT_ID} &>/dev/null

# Fonction de vérification générique
check_resources() {
    local resource_type=$1
    local command=$2
    local description=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    log_info "Vérification: ${description}..."
    
    local result=$(eval "$command" 2>/dev/null)
    
    if [ -z "$result" ]; then
        log_ok "Aucune ressource trouvée pour: ${description}"
        return 0
    else
        log_found "Ressources trouvées pour: ${description}"
        echo "$result" | while read line; do
            echo "    └─ ${line}"
        done
        RESOURCES_FOUND=$((RESOURCES_FOUND + 1))
        return 1
    fi
}

echo -e "${BLUE}Début de la vérification...${NC}"
echo ""

# ============================================
# 1. Cloud Run Services
# ============================================
echo -e "${YELLOW}=== Cloud Run Services ===${NC}"
check_resources "cloudrun" \
    "gcloud run services list --region=${REGION} --filter='metadata.name~${PREFIX}' --format='table(metadata.name,status.url)'" \
    "Cloud Run services"
echo ""

# ============================================
# 2. Load Balancer Components
# ============================================
echo -e "${YELLOW}=== Load Balancer Components ===${NC}"

check_resources "forwarding-rules" \
    "gcloud compute forwarding-rules list --global --filter='name~${PREFIX}' --format='table(name,IPAddress)'" \
    "Forwarding rules"

check_resources "target-https-proxies" \
    "gcloud compute target-https-proxies list --filter='name~${PREFIX}' --format='table(name)'" \
    "HTTPS proxies"

check_resources "url-maps" \
    "gcloud compute url-maps list --filter='name~${PREFIX}' --format='table(name)'" \
    "URL maps"

check_resources "backend-services" \
    "gcloud compute backend-services list --global --filter='name~${PREFIX}' --format='table(name)'" \
    "Backend services"

check_resources "network-endpoint-groups" \
    "gcloud compute network-endpoint-groups list --regions=${REGION} --filter='name~${PREFIX}' --format='table(name,region)'" \
    "Network Endpoint Groups"

check_resources "ssl-certificates" \
    "gcloud compute ssl-certificates list --filter='name~${PREFIX}' --format='table(name,managed.status)'" \
    "SSL certificates"
echo ""

# ============================================
# 3. Cloud SQL
# ============================================
echo -e "${YELLOW}=== Cloud SQL ===${NC}"
check_resources "cloudsql" \
    "gcloud sql instances list --filter='name~${PREFIX}' --format='table(name,region,databaseVersion)'" \
    "Cloud SQL instances"
echo ""

# ============================================
# 4. Redis
# ============================================
echo -e "${YELLOW}=== Redis ===${NC}"
check_resources "redis" \
    "gcloud redis instances list --region=${REGION} --filter='name~${PREFIX}' --format='table(name,region,tier)'" \
    "Redis instances"
echo ""

# ============================================
# 5. VPC Connector
# ============================================
echo -e "${YELLOW}=== VPC Connector ===${NC}"
check_resources "vpc-connector" \
    "gcloud compute networks vpc-access connectors list --region=${REGION} --filter='name~${PREFIX}' --format='table(name,region)'" \
    "VPC Connectors"
echo ""

# ============================================
# 6. Compute Engine VMs
# ============================================
echo -e "${YELLOW}=== Compute Engine VMs ===${NC}"
check_resources "compute-instances" \
    "gcloud compute instances list --zones=${BASTION_ZONE} --filter='name~${PREFIX}' --format='table(name,zone,machineType)'" \
    "Compute Engine instances"
echo ""

# ============================================
# 7. Disques persistants
# ============================================
echo -e "${YELLOW}=== Disques Persistants ===${NC}"
check_resources "disks" \
    "gcloud compute disks list --zones=${BASTION_ZONE} --filter='name~${PREFIX}' --format='table(name,zone,sizeGb)'" \
    "Disques persistants"
echo ""

# ============================================
# 8. Firewall Rules
# ============================================
echo -e "${YELLOW}=== Firewall Rules ===${NC}"
check_resources "firewall-rules" \
    "gcloud compute firewall-rules list --filter='name~${PREFIX}' --format='table(name,direction,priority)'" \
    "Règles de firewall"
echo ""

# ============================================
# 9. VPC Network et Subnets
# ============================================
echo -e "${YELLOW}=== VPC Network ===${NC}"
check_resources "networks" \
    "gcloud compute networks list --filter='name~${PREFIX}' --format='table(name,autoCreateSubnetworks)'" \
    "VPC Networks"

check_resources "subnets" \
    "gcloud compute networks subnets list --regions=${REGION} --filter='name~${PREFIX}' --format='table(name,region,ipCidrRange)'" \
    "Subnets"
echo ""

# ============================================
# 10. Secrets
# ============================================
echo -e "${YELLOW}=== Secret Manager ===${NC}"
check_resources "secrets" \
    "gcloud secrets list --filter='name~${PREFIX}' --format='table(name)'" \
    "Secrets"
echo ""

# ============================================
# 11. Service Accounts
# ============================================
echo -e "${YELLOW}=== Service Accounts ===${NC}"
check_resources "service-accounts" \
    "gcloud iam service-accounts list --filter='email~${PREFIX}' --format='table(email)'" \
    "Service Accounts"
echo ""

# ============================================
# 12. Vérifications supplémentaires
# ============================================
echo -e "${YELLOW}=== Vérifications Supplémentaires ===${NC}"

# Adresses IP réservées
check_resources "addresses" \
    "gcloud compute addresses list --global --filter='name~${PREFIX}' --format='table(name,address)'" \
    "Adresses IP réservées"

# Routers (si NAT était utilisé)
check_resources "routers" \
    "gcloud compute routers list --regions=${REGION} --filter='name~${PREFIX}' --format='table(name,region)'" \
    "Cloud Routers"

# IAM bindings custom (difficile à vérifier automatiquement, juste une note)
log_info "Note: Les IAM bindings personnalisés ne sont pas vérifiés automatiquement."

echo ""

# ============================================
# Résumé Final
# ============================================
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Résumé de la Vérification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Total de vérifications: ${TOTAL_CHECKS}"

if [ $RESOURCES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ Toutes les ressources ont été supprimées avec succès !${NC}"
    echo ""
    log_info "Votre projet GCP est propre."
    exit 0
else
    echo -e "${RED}✗ ${RESOURCES_FOUND} type(s) de ressources trouvées${NC}"
    echo ""
    log_warn "Certaines ressources n'ont pas été supprimées."
    log_info "Consultez les détails ci-dessus pour identifier les ressources restantes."
    log_info "Vous pouvez les supprimer manuellement via la console GCP ou en réexécutant le script de nettoyage."
    echo ""
    log_info "Console GCP: https://console.cloud.google.com/home/dashboard?project=${PROJECT_ID}"
    exit 1
fi
