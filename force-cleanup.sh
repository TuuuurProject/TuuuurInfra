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
echo -e "${BLUE}  GCP Force Cleanup Script${NC}"
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

# Vérifier que gcloud est installé
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI n'est pas installé."
    exit 1
fi

# Définir le projet
log_info "Définition du projet GCP: ${PROJECT_ID}"
gcloud config set project ${PROJECT_ID}

echo ""
log_warn "Ce script va forcer la suppression des ressources restantes."
echo ""

# Fonction pour supprimer une ressource avec retry
force_delete() {
    local description=$1
    local command=$2
    local max_attempts=3
    local attempt=1
    
    log_info "Tentative de suppression: ${description}"
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command" 2>/dev/null; then
            log_info "✓ Supprimé avec succès: ${description}"
            return 0
        else
            log_warn "Tentative ${attempt}/${max_attempts} échouée pour: ${description}"
            attempt=$((attempt + 1))
            if [ $attempt -le $max_attempts ]; then
                log_info "Attente de 5 secondes avant nouvelle tentative..."
                sleep 5
            fi
        fi
    done
    
    log_error "✗ Impossible de supprimer après ${max_attempts} tentatives: ${description}"
    return 1
}

# ============================================
# 1. Supprimer Redis avec force
# ============================================
log_info "Suppression forcée de Redis..."

REDIS_INSTANCE="${PREFIX}-redis"
if gcloud redis instances list --region=${REGION} --filter="name=${REDIS_INSTANCE}" --format="value(name)" 2>/dev/null | grep -q "${REDIS_INSTANCE}"; then
    force_delete "Redis instance: ${REDIS_INSTANCE}" \
        "gcloud redis instances delete ${REDIS_INSTANCE} --region=${REGION} --quiet"
else
    log_info "Redis instance ${REDIS_INSTANCE} n'existe plus"
fi

# ============================================
# 2. Supprimer le VPC Network restant
# ============================================
log_info "Suppression forcée du VPC Network..."

NETWORK_NAME="${PREFIX}-vpc"

# D'abord, lister et supprimer tous les peerings
log_info "Recherche des peerings sur le réseau ${NETWORK_NAME}..."
PEERINGS=$(gcloud compute networks peerings list --network=${NETWORK_NAME} --format="value(name)" 2>/dev/null || echo "")

if [ ! -z "$PEERINGS" ]; then
    for peering in $PEERINGS; do
        log_info "Suppression du peering: ${peering}"
        force_delete "Peering: ${peering}" \
            "gcloud compute networks peerings delete ${peering} --network=${NETWORK_NAME} --quiet"
    done
fi

# Supprimer les allocated IP ranges pour Private Service Connection
log_info "Tentative de suppression des allocated IP ranges..."
gcloud compute addresses list --global --filter="purpose=VPC_PEERING AND network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null | while read addr; do
    if [ ! -z "$addr" ]; then
        log_info "Suppression de l'adresse allouée: ${addr}"
        force_delete "Address: ${addr}" \
            "gcloud compute addresses delete ${addr} --global --quiet"
    fi
done

# Supprimer les routes personnalisées
log_info "Recherche des routes personnalisées..."
ROUTES=$(gcloud compute routes list --filter="network~${NETWORK_NAME} AND nextHopNetwork!=''" --format="value(name)" 2>/dev/null || echo "")

if [ ! -z "$ROUTES" ]; then
    for route in $ROUTES; do
        log_info "Suppression de la route: ${route}"
        force_delete "Route: ${route}" \
            "gcloud compute routes delete ${route} --quiet"
    done
fi

# Supprimer tous les subnets restants
log_info "Recherche des subnets restants..."
SUBNETS=$(gcloud compute networks subnets list --network=${NETWORK_NAME} --format="value(name,region)" 2>/dev/null || echo "")

if [ ! -z "$SUBNETS" ]; then
    echo "$SUBNETS" | while read subnet_info; do
        if [ ! -z "$subnet_info" ]; then
            subnet_name=$(echo $subnet_info | awk '{print $1}')
            subnet_region=$(echo $subnet_info | awk '{print $2}')
            log_info "Suppression du subnet: ${subnet_name} (région: ${subnet_region})"
            force_delete "Subnet: ${subnet_name}" \
                "gcloud compute networks subnets delete ${subnet_name} --region=${subnet_region} --quiet"
        fi
    done
fi

# Supprimer toutes les règles de firewall restantes
log_info "Recherche des règles de firewall restantes sur ${NETWORK_NAME}..."
FIREWALL_RULES=$(gcloud compute firewall-rules list --filter="network~${NETWORK_NAME}" --format="value(name)" 2>/dev/null || echo "")

if [ ! -z "$FIREWALL_RULES" ]; then
    for rule in $FIREWALL_RULES; do
        log_info "Suppression de la règle de firewall: ${rule}"
        force_delete "Firewall rule: ${rule}" \
            "gcloud compute firewall-rules delete ${rule} --quiet"
    done
fi

# Enfin, supprimer le réseau
log_info "Tentative finale de suppression du réseau VPC..."
if gcloud compute networks list --filter="name=${NETWORK_NAME}" --format="value(name)" 2>/dev/null | grep -q "${NETWORK_NAME}"; then
    force_delete "VPC Network: ${NETWORK_NAME}" \
        "gcloud compute networks delete ${NETWORK_NAME} --quiet"
else
    log_info "VPC Network ${NETWORK_NAME} n'existe plus"
fi

# ============================================
# 3. Nettoyage des ressources orphelines
# ============================================
log_info "Recherche de ressources orphelines..."

# Adresses IP globales orphelines
log_info "Recherche des adresses IP globales orphelines..."
ORPHAN_IPS=$(gcloud compute addresses list --global --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")

if [ ! -z "$ORPHAN_IPS" ]; then
    for ip in $ORPHAN_IPS; do
        log_info "Suppression de l'adresse IP: ${ip}"
        force_delete "Address: ${ip}" \
            "gcloud compute addresses delete ${ip} --global --quiet"
    done
fi

# Adresses IP régionales orphelines
log_info "Recherche des adresses IP régionales orphelines..."
ORPHAN_REGIONAL_IPS=$(gcloud compute addresses list --regions=${REGION} --filter="name~${PREFIX}" --format="value(name)" 2>/dev/null || echo "")

if [ ! -z "$ORPHAN_REGIONAL_IPS" ]; then
    for ip in $ORPHAN_REGIONAL_IPS; do
        log_info "Suppression de l'adresse IP régionale: ${ip}"
        force_delete "Regional Address: ${ip}" \
            "gcloud compute addresses delete ${ip} --region=${REGION} --quiet"
    done
fi

# ============================================
# Résumé
# ============================================
echo ""
log_info "========================================="
log_info "Nettoyage forcé terminé !"
log_info "========================================="
echo ""
log_info "Exécutez à nouveau ./verify-cleanup.sh pour vérifier."
echo ""
