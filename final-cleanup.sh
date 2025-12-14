#!/bin/bash

# Configuration
PROJECT_ID="tuuuur"
REGION="europe-west9"
NETWORK_NAME="webplat-stage-vpc"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

gcloud config set project ${PROJECT_ID} &>/dev/null

echo -e "${GREEN}========================================"
echo "  Final Cleanup - Étape par étape"
echo -e "========================================${NC}"
echo ""

# Étape 1: Supprimer la règle de firewall restante
log_info "Étape 1: Suppression de la règle de firewall restante..."
FIREWALL="aet-europewest9-webplat--stage--vpc-rsgfw"
if gcloud compute firewall-rules describe ${FIREWALL} &>/dev/null; then
    gcloud compute firewall-rules delete ${FIREWALL} --quiet 2>/dev/null && \
        log_info "✓ Règle firewall ${FIREWALL} supprimée" || \
        log_error "✗ Impossible de supprimer ${FIREWALL}"
else
    log_info "✓ Règle firewall déjà supprimée"
fi

sleep 3

# Étape 2: Supprimer le peering Redis
log_info "Étape 2: Suppression du peering Redis..."
REDIS_PEER="redis-peer-264533917558"
if gcloud compute networks peerings list --network=${NETWORK_NAME} --format="value(name)" 2>/dev/null | grep -q "^${REDIS_PEER}$"; then
    gcloud compute networks peerings delete ${REDIS_PEER} --network=${NETWORK_NAME} --quiet 2>/dev/null && \
        log_info "✓ Peering Redis supprimé" || \
        log_error "✗ Impossible de supprimer le peering Redis"
    sleep 5
else
    log_info "✓ Peering Redis déjà supprimé"
fi

# Étape 3: Supprimer le peering Service Networking
log_info "Étape 3: Suppression du peering Service Networking..."
SNET_PEER="servicenetworking-googleapis-com"
if gcloud compute networks peerings list --network=${NETWORK_NAME} --format="value(name)" 2>/dev/null | grep -q "^${SNET_PEER}$"; then
    gcloud compute networks peerings delete ${SNET_PEER} --network=${NETWORK_NAME} --quiet 2>/dev/null && \
        log_info "✓ Peering Service Networking supprimé" || \
        log_error "✗ Impossible de supprimer le peering Service Networking"
    sleep 5
else
    log_info "✓ Peering Service Networking déjà supprimé"
fi

# Étape 4: Supprimer le subnet connector
log_info "Étape 4: Suppression du subnet connector..."
SUBNET="webplat-stage-connector-europe-west9"
if gcloud compute networks subnets describe ${SUBNET} --region=${REGION} &>/dev/null; then
    gcloud compute networks subnets delete ${SUBNET} --region=${REGION} --quiet 2>/dev/null && \
        log_info "✓ Subnet connector supprimé" || \
        log_error "✗ Impossible de supprimer le subnet connector"
    sleep 3
else
    log_info "✓ Subnet connector déjà supprimé"
fi

# Étape 5: Supprimer le réseau VPC
log_info "Étape 5: Suppression du réseau VPC..."
if gcloud compute networks describe ${NETWORK_NAME} &>/dev/null; then
    gcloud compute networks delete ${NETWORK_NAME} --quiet 2>/dev/null && \
        log_info "✓ Réseau VPC supprimé avec succès !" || \
        log_error "✗ Impossible de supprimer le réseau VPC"
else
    log_info "✓ Réseau VPC déjà supprimé"
fi

echo ""
log_info "========================================"
log_info "✓ Nettoyage terminé !"
log_info "========================================"
echo ""
log_info "Vérification finale avec: ./verify-cleanup.sh"
