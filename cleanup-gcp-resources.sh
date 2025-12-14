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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  GCP Resource Cleanup Script${NC}"
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

# Fonction pour demander confirmation
confirm() {
    read -p "$(echo -e ${YELLOW}$1${NC}) [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI n'est pas installé. Veuillez l'installer d'abord."
    exit 1
fi

# Vérifier le projet
log_info "Définition du projet GCP: ${PROJECT_ID}"
gcloud config set project ${PROJECT_ID}

echo ""
log_warn "⚠️  Ce script va supprimer TOUTES les ressources suivantes:"
echo "  - Cloud Run services (front, api)"
echo "  - Load Balancers (certificats SSL, NEGs, backends, URLs maps, proxies, forwarding rules)"
echo "  - Cloud SQL instances"
echo "  - Compute Engine VMs (bastion, SQL VM si présent)"
echo "  - VPC Connector"
echo "  - Redis instances"
echo "  - Service Accounts"
echo "  - Secret Manager secrets"
echo "  - VPC Network, Subnets, Firewall rules"
echo "  - Compute disks"
echo ""

if ! confirm "Êtes-vous ABSOLUMENT SÛR de vouloir continuer?"; then
    log_info "Annulation de l'opération."
    exit 0
fi

echo ""
log_info "Début de la suppression des ressources..."
echo ""

# ============================================
# 1. Supprimer les Load Balancers (dans l'ordre)
# ============================================
log_info "Suppression des Load Balancers..."

# Forwarding rules
for service in front api; do
    RULE_NAME="${PREFIX}-${service}-lb"
    if gcloud compute forwarding-rules list --global --filter="name=${RULE_NAME}" --format="value(name)" 2>/dev/null | grep -q "${RULE_NAME}"; then
        log_info "Suppression de la forwarding rule: ${RULE_NAME}"
        gcloud compute forwarding-rules delete ${RULE_NAME} --global --quiet 2>/dev/null || log_warn "Impossible de supprimer ${RULE_NAME}"
    fi
done

# Target HTTPS proxies
for service in front api; do
    PROXY_NAME="${PREFIX}-${service}-https-proxy"
    if gcloud compute target-https-proxies list --filter="name=${PROXY_NAME}" --format="value(name)" 2>/dev/null | grep -q "${PROXY_NAME}"; then
        log_info "Suppression du HTTPS proxy: ${PROXY_NAME}"
        gcloud compute target-https-proxies delete ${PROXY_NAME} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${PROXY_NAME}"
    fi
done

# URL maps
for service in front api; do
    URLMAP_NAME="${PREFIX}-${service}-url-map"
    if gcloud compute url-maps list --filter="name=${URLMAP_NAME}" --format="value(name)" 2>/dev/null | grep -q "${URLMAP_NAME}"; then
        log_info "Suppression de l'URL map: ${URLMAP_NAME}"
        gcloud compute url-maps delete ${URLMAP_NAME} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${URLMAP_NAME}"
    fi
done

# Backend services
for service in front api; do
    BACKEND_NAME="${PREFIX}-${service}-backend"
    if gcloud compute backend-services list --global --filter="name=${BACKEND_NAME}" --format="value(name)" 2>/dev/null | grep -q "${BACKEND_NAME}"; then
        log_info "Suppression du backend service: ${BACKEND_NAME}"
        gcloud compute backend-services delete ${BACKEND_NAME} --global --quiet 2>/dev/null || log_warn "Impossible de supprimer ${BACKEND_NAME}"
    fi
done

# Network Endpoint Groups (NEG)
for service in front api; do
    NEG_NAME="${PREFIX}-${service}-neg"
    if gcloud compute network-endpoint-groups list --regions=${REGION} --filter="name=${NEG_NAME}" --format="value(name)" 2>/dev/null | grep -q "${NEG_NAME}"; then
        log_info "Suppression du NEG: ${NEG_NAME}"
        gcloud compute network-endpoint-groups delete ${NEG_NAME} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${NEG_NAME}"
    fi
done

# SSL Certificates
log_info "Recherche des certificats SSL à supprimer..."
CERTS=$(gcloud compute ssl-certificates list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for cert in $CERTS; do
    log_info "Suppression du certificat SSL: ${cert}"
    gcloud compute ssl-certificates delete ${cert} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${cert}"
done

# ============================================
# 2. Supprimer les Cloud Run services
# ============================================
log_info "Suppression des Cloud Run services..."

for service in front api; do
    SERVICE_NAME="${PREFIX}-${service}"
    if gcloud run services list --region=${REGION} --filter="metadata.name=${SERVICE_NAME}" --format="value(metadata.name)" 2>/dev/null | grep -q "${SERVICE_NAME}"; then
        log_info "Suppression du Cloud Run service: ${SERVICE_NAME}"
        gcloud run services delete ${SERVICE_NAME} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${SERVICE_NAME}"
    fi
done

# ============================================
# 3. Supprimer Cloud SQL
# ============================================
log_info "Suppression des instances Cloud SQL..."

SQL_INSTANCE="${PREFIX}-sql"
if gcloud sql instances list --filter="name=${SQL_INSTANCE}" --format="value(name)" 2>/dev/null | grep -q "${SQL_INSTANCE}"; then
    log_info "Suppression de l'instance Cloud SQL: ${SQL_INSTANCE}"
    gcloud sql instances delete ${SQL_INSTANCE} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${SQL_INSTANCE}"
fi

# ============================================
# 4. Supprimer Redis
# ============================================
log_info "Suppression des instances Redis..."

REDIS_INSTANCE="${PREFIX}-redis"
if gcloud redis instances list --region=${REGION} --filter="name=${REDIS_INSTANCE}" --format="value(name)" 2>/dev/null | grep -q "${REDIS_INSTANCE}"; then
    log_info "Suppression de l'instance Redis: ${REDIS_INSTANCE}"
    gcloud redis instances delete ${REDIS_INSTANCE} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${REDIS_INSTANCE}"
fi

# ============================================
# 5. Supprimer VPC Connector
# ============================================
log_info "Suppression du VPC Connector..."

CONNECTOR_NAME="${PREFIX}-connector"
if gcloud compute networks vpc-access connectors list --region=${REGION} --filter="name=${CONNECTOR_NAME}" --format="value(name)" 2>/dev/null | grep -q "${CONNECTOR_NAME}"; then
    log_info "Suppression du VPC Connector: ${CONNECTOR_NAME}"
    gcloud compute networks vpc-access connectors delete ${CONNECTOR_NAME} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${CONNECTOR_NAME}"
fi

# ============================================
# 6. Supprimer les VMs (Bastion + SQL VM éventuel)
# ============================================
log_info "Suppression des VMs Compute Engine..."

# Bastion
BASTION_NAME="${PREFIX}-bastion"
BASTION_ZONE="europe-west9-b"
if gcloud compute instances list --zones=${BASTION_ZONE} --filter="name=${BASTION_NAME}" --format="value(name)" 2>/dev/null | grep -q "${BASTION_NAME}"; then
    log_info "Suppression du bastion: ${BASTION_NAME}"
    gcloud compute instances delete ${BASTION_NAME} --zone=${BASTION_ZONE} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${BASTION_NAME}"
fi

# SQL VM (si existe)
SQL_VM_NAME="${PREFIX}-sql-vm"
if gcloud compute instances list --zones=${BASTION_ZONE} --filter="name=${SQL_VM_NAME}" --format="value(name)" 2>/dev/null | grep -q "${SQL_VM_NAME}"; then
    log_info "Suppression de la VM SQL: ${SQL_VM_NAME}"
    gcloud compute instances delete ${SQL_VM_NAME} --zone=${BASTION_ZONE} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${SQL_VM_NAME}"
fi

# ============================================
# 7. Supprimer les disques persistants orphelins
# ============================================
log_info "Suppression des disques persistants..."

DISKS=$(gcloud compute disks list --zones=${BASTION_ZONE} --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for disk in $DISKS; do
    log_info "Suppression du disque: ${disk}"
    gcloud compute disks delete ${disk} --zone=${BASTION_ZONE} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${disk}"
done

# ============================================
# 8. Supprimer les règles de firewall
# ============================================
log_info "Suppression des règles de firewall..."

FIREWALL_RULES=$(gcloud compute firewall-rules list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for rule in $FIREWALL_RULES; do
    log_info "Suppression de la règle de firewall: ${rule}"
    gcloud compute firewall-rules delete ${rule} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${rule}"
done

# ============================================
# 9. Supprimer le peering pour Private Service Access
# ============================================
log_info "Suppression du peering Private Service Access..."

NETWORK_NAME="${PREFIX}-vpc"
PEERING_NAME="servicenetworking-googleapis-com"
if gcloud compute networks peerings list --network=${NETWORK_NAME} --format="value(name)" 2>/dev/null | grep -q "${PEERING_NAME}"; then
    log_info "Suppression du peering: ${PEERING_NAME}"
    gcloud compute networks peerings delete ${PEERING_NAME} --network=${NETWORK_NAME} --quiet 2>/dev/null || log_warn "Impossible de supprimer le peering"
fi

# Supprimer le range alloué pour Private Service Access
log_info "Suppression des IP ranges allouées pour Private Service Access..."
gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=${NETWORK_NAME} \
    --quiet 2>/dev/null || log_warn "Impossible de supprimer les IP ranges"

# ============================================
# 10. Supprimer les subnets
# ============================================
log_info "Suppression des subnets..."

for subnet in app admin connector; do
    SUBNET_NAME="${PREFIX}-${subnet}"
    if gcloud compute networks subnets list --regions=${REGION} --filter="name=${SUBNET_NAME}" --format="value(name)" 2>/dev/null | grep -q "${SUBNET_NAME}"; then
        log_info "Suppression du subnet: ${SUBNET_NAME}"
        gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${SUBNET_NAME}"
    fi
done

# ============================================
# 11. Supprimer le réseau VPC
# ============================================
log_info "Suppression du réseau VPC..."

if gcloud compute networks list --filter="name=${NETWORK_NAME}" --format="value(name)" 2>/dev/null | grep -q "${NETWORK_NAME}"; then
    log_info "Suppression du réseau: ${NETWORK_NAME}"
    gcloud compute networks delete ${NETWORK_NAME} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${NETWORK_NAME}"
fi

# ============================================
# 12. Supprimer les secrets
# ============================================
log_info "Suppression des secrets..."

SECRETS=$(gcloud secrets list --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null)
for secret in $SECRETS; do
    log_info "Suppression du secret: ${secret}"
    gcloud secrets delete ${secret} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${secret}"
done

# ============================================
# 13. Supprimer les Service Accounts
# ============================================
log_info "Suppression des Service Accounts..."

for sa in front api; do
    SA_EMAIL="${PREFIX}-${sa}@${PROJECT_ID}.iam.gserviceaccount.com"
    if gcloud iam service-accounts list --filter="email=${SA_EMAIL}" --format="value(email)" 2>/dev/null | grep -q "${SA_EMAIL}"; then
        log_info "Suppression du Service Account: ${SA_EMAIL}"
        gcloud iam service-accounts delete ${SA_EMAIL} --quiet 2>/dev/null || log_warn "Impossible de supprimer ${SA_EMAIL}"
    fi
done

# ============================================
# Résumé
# ============================================
echo ""
log_info "========================================="
log_info "Nettoyage terminé !"
log_info "========================================="
echo ""
log_info "Ressources supprimées (ou tentatives):"
echo "  ✓ Load Balancers et composants (forwarding rules, proxies, URL maps, backends, NEGs, certificats SSL)"
echo "  ✓ Cloud Run services (front, api)"
echo "  ✓ Cloud SQL instances"
echo "  ✓ Redis instances"
echo "  ✓ VPC Connector"
echo "  ✓ Compute Engine VMs (bastion, SQL VM)"
echo "  ✓ Disques persistants"
echo "  ✓ Règles de firewall"
echo "  ✓ VPC Network et Subnets"
echo "  ✓ Private Service Access peering"
echo "  ✓ Secrets"
echo "  ✓ Service Accounts"
echo ""
log_warn "Note: Certaines ressources peuvent avoir échoué si elles n'existaient pas ou avaient des dépendances."
log_info "Vérifiez la console GCP pour confirmer que tout a été supprimé: https://console.cloud.google.com/home/dashboard?project=${PROJECT_ID}"
echo ""
log_info "Si vous avez un backend Terraform (GCS bucket), vous pouvez aussi le supprimer manuellement si nécessaire."
echo ""
